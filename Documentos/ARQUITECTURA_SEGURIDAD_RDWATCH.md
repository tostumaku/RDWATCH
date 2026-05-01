# DOCUMENTO OFICIAL DE ARQUITECTURA, SEGURIDAD Y FLUJO DE DATOS
## Sistema RD-WATCH v3.0
**Clasificación:** Documento Técnico Interno — Uso exclusivo para desarrolladores y auditores  
**Fecha de emisión:** 2026-04-30  
**Redactado por:** Arquitectura de Software / Ciberseguridad

---

## 1. ESTRUCTURA GENERAL Y FLUJO DE LA ARQUITECTURA

### 1.1 Modelo Arquitectónico: MVC Modificado con Ocultación Total

RD-WATCH implementa una arquitectura **Model-View-Controller (MVC)** de cuatro capas con un principio rector denominado **"Ocultación Total"**: la capa PHP (Controller) no conoce nombres de tablas ni columnas de la base de datos. Toda interacción con el modelo de datos se realiza exclusivamente a través de funciones PL/pgSQL que retornan JSON puro.

| Capa | Tecnología | Responsabilidad |
|------|-----------|----------------|
| **Vista** | HTML5 + CSS3 | Estructura visual, formularios, renderizado |
| **Orquestador** | JavaScript (ES6+) | Captura de eventos, peticiones asíncronas, renderizado dinámico |
| **Controlador** | PHP 8.x + PDO | Validación de sesión/CSRF, sanitización, proxy JSON |
| **Modelo** | PostgreSQL + PL/pgSQL | Reglas de negocio, validaciones de integridad, transacciones ACID |

### 1.2 Puente de Comunicación: Flujo Completo de una Operación

**Ejemplo: Creación de un producto desde el panel de administración.**

**Paso 1 — Vista (HTML):** El administrador completa el formulario `#formProducto` en `src/admin/admin.html` y pulsa "Guardar".

**Paso 2 — Orquestador (JavaScript):** El archivo `src/admin/admin.js` captura el evento `submit`, construye un objeto JSON con los campos del formulario y ejecuta:
```javascript
const res = await secureFetch(`${API_BASE}/productos.php`, {
    method: 'POST',
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify(payload)
});
```
La función `secureFetch()` (definida en `src/js/security.js`) inyecta automáticamente el token CSRF en el header `X-CSRF-Token` y fuerza `credentials: 'include'` para transmitir la cookie de sesión PHP.

**Paso 3 — Controlador (PHP):** El archivo `src/backend/api/productos.php` recibe la petición:
1. Verifica rol administrador mediante `requireRole('admin')`.
2. Valida el token CSRF con `validateCsrfToken()`.
3. Valida formato de campos con `Validation::validateOrReject()`.
4. Ejecuta la consulta opaca hacia PostgreSQL:
```php
$stmt = $pdo->prepare("SELECT fn_cat_create_producto(?, ?, ?, ?, ?::smallint, ?, ?, ?, ?, ?)");
$stmt->execute([...parámetros...]);
$jsonResponse = $stmt->fetchColumn();
echo $jsonResponse;
```

**Paso 4 — Modelo (PL/pgSQL):** La función `fn_cat_create_producto` en `catalog_master.sql` ejecuta 3 validaciones de integridad (PK duplicada, nombre+marca duplicado, coherencia categoría↔subcategoría), realiza el INSERT si todo es correcto, y retorna:
```json
{"ok": true, "msg": "El reloj ha sido integrado al catálogo exitosamente."}
```

**Paso 5 — Retorno:** PHP imprime el JSON tal cual → JavaScript lo parsea → Si `data.ok === true`, cierra el modal y recarga la tabla.

### 1.3 Inventario de Módulos SQL (70 funciones en 5 fases)

| Fase | Archivo | Funciones | Dominio |
|------|---------|-----------|---------|
| 1 | `auth_security.sql` | 9 | Autenticación, rate limiting, recuperación de contraseña |
| 2 | `catalog_master.sql` | 23 | Productos, marcas, categorías, subcategorías, servicios |
| 3 | `ecommerce_core.sql` | 15 | Carrito, checkout atómico, pedidos, citas/reservas |
| 4 | `client_panel.sql` | 16 | Panel de usuario, reseñas, geografía, admin de clientes |
| 5 | `admin_reports.sql` | 7 | Dashboard KPIs, facturación, comprobantes, config bancaria |

### 1.4 Inventario de Endpoints PHP (29 archivos API)

Organizados en `src/backend/api/`, incluyen: `login.php`, `signup.php`, `logout.php`, `me.php`, `productos.php`, `checkout.php`, `pedidos.php`, `carrito.php`, `citas.php`, `servicios.php`, `categorias.php`, `marcas.php`, `catalogos.php`, `clientes.php`, `resenas.php`, `stats.php`, `get_factura.php`, `get_comprobante.php`, `forgot_password.php`, `reset_password.php`, `contacto.php`, `ciudades.php`, `admin_settings.php`, `auth_google.php`, entre otros.

---

## 2. CARGA INICIAL Y ARQUITECTURA POST-LOGIN

### 2.1 Landing Page (`index.html`)

La primera petición del usuario carga:

| Recurso | Tipo | Propósito |
|---------|------|-----------|
| `index.html` (33 KB) | DOM | Estructura semántica completa: hero, servicios, galería, contacto, modales de auth |
| `src/css/style.css` (82 KB) | CSS | Sistema de diseño completo con versionado de caché (`?v=1.1`) |
| Google Fonts (Playfair Display + Montserrat) | CDN | Tipografía premium con `crossorigin="anonymous"` |
| Font Awesome 6.x | CDN con SRI | Iconografía con verificación de integridad (`integrity="sha384-..."`) |
| `src/css/hero_video.mp4` | Media | Video hero con atributos `autoplay muted loop playsinline` |
| `src/js/config.js` | JS | Detección dinámica de la URL base de la API |
| `src/js/notifications.js` | JS | Sistema de notificaciones toast |
| `src/js/security.js` | JS | Wrapper `secureFetch()` con inyección CSRF |
| `src/js/script.js` (82 KB) | JS | Lógica de la landing: login, signup, carrito, catálogo |
| Google Identity Services | CDN | OAuth 2.0 con Google (carga asíncrona: `async defer`) |

**Optimizaciones de velocidad:**
- Preloader animado con reloj CSS mientras cargan los assets pesados.
- Videos con `playsinline` + `muted` para autoplay sin bloqueo del navegador.
- Scripts cargados al final del `<body>` para no bloquear el renderizado del DOM.
- Versionado de caché en CSS/JS (`?v=1.1`) para invalidación controlada.

### 2.2 Ecosistema Post-Login

#### 2.2.1 Proceso de Autenticación

1. El usuario envía credenciales desde el modal `#loginForm` vía `secureFetch()` a `login.php`.
2. **Rate Limiting:** `fn_sec_check_rate_limit(IP, 'login_attempt', 5, 15)` verifica que la IP no haya excedido 5 intentos en 15 minutos. Si está bloqueada → HTTP 429.
3. **Búsqueda opaca:** `fn_auth_get_user(email)` retorna JSON con `{id, nombre, hash, rol, activo, bloqueado}` o NULL.
4. **Verificación de contraseña:** PHP ejecuta `password_verify($pass, $user['contra'])` comparando contra el hash bcrypt.
5. **Migración legacy:** Si `password_verify` falla pero la contraseña coincide en texto plano, PHP genera un nuevo hash bcrypt y lo actualiza vía `fn_auth_update_hash()`.
6. **Creación de sesión:** Tras éxito, PHP ejecuta `session_regenerate_id(true)` (anti session fixation) y establece:

```php
$_SESSION['user_id']   = $user['id_usuario'];
$_SESSION['user_role'] = $user['rol'];        // 'admin' o 'cliente'
$_SESSION['user_name'] = $user['nom_usuario'];
$_SESSION['logged_in'] = true;
```

7. **Limpieza:** `fn_sec_clear_attempts(IP, 'login_attempt')` borra los intentos fallidos previos.
8. **Respuesta:** PHP retorna URL de redirección según rol: `src/admin/admin.html` o `src/user/user.html`.

#### 2.2.2 Validación de Roles y Restricción de Endpoints

Cada endpoint protegido invoca una de estas funciones al inicio:

- `requireLogin()` — Verifica `$_SESSION['logged_in'] === true`. Si no → HTTP 401.
- `requireRole('admin')` — Invoca primero `requireLogin()`, luego verifica `$_SESSION['user_role'] === 'admin'`. Si no → HTTP 403.

Los endpoints de checkout, carrito y panel de usuario verifican `$_SESSION['user_id']` directamente. Los de gestión de inventario, pedidos y clientes exigen `requireRole('admin')`.

#### 2.2.3 Verificación Continua de Sesión

Cada panel (admin/cliente) ejecuta al cargar una verificación de sesión activa contra `me.php`, que internamente llama a `fn_auth_get_session(user_id)`. Si la sesión expiró o el rol no coincide, el usuario es redirigido a `index.html` usando `window.location.replace()` para eliminar la página protegida del historial del navegador.

---

## 3. BLINDAJE DE SEGURIDAD Y CRIPTOGRAFÍA

### 3.1 Estrategia de Seguridad en Tres Capas

#### Capa 1: Cliente (JavaScript + HTML)

| Mecanismo | Implementación |
|-----------|---------------|
| **Anti-XSS en formularios** | Atributos HTML5 (`type="email"`, `maxlength`, `pattern`) para validación previa |
| **CSRF Token injection** | `secureFetch()` inyecta header `X-CSRF-Token` en toda petición mutante (POST/PUT/DELETE) |
| **Credential isolation** | `credentials: 'include'` envía cookies de sesión; nunca se almacenan tokens en localStorage |
| **Medidor de contraseña** | Validación visual en tiempo real (longitud, mayúsculas, números, caracteres especiales) |
| **Redirección segura** | `window.location.replace()` elimina páginas protegidas del historial del navegador |

#### Capa 2: Servidor (PHP)

| Mecanismo | Archivo | Detalle |
|-----------|---------|---------|
| **Headers de seguridad** | `config.php` | `X-Frame-Options: DENY`, `X-Content-Type-Options: nosniff`, `X-XSS-Protection: 1; mode=block`, `Referrer-Policy: strict-origin-when-cross-origin` |
| **Content Security Policy** | `config.php` | CSP que restringe scripts a `'self'` y CDNs autorizados (jsdelivr, cloudflare, googleapis, stripe) |
| **Cache-Control** | `config.php` | `no-cache, no-store, must-revalidate` para datos sensibles |
| **CORS controlado** | `config.php` | Origin reflejado dinámicamente (nunca `*`), con `Allow-Credentials: true` |
| **Cookies seguras** | `config.php` | `httponly=1`, `use_only_cookies=1`, `samesite=Lax`, `path=/` |
| **Sanitización XSS** | `security_utils.php` | `sanitizeHtml()` aplica `htmlspecialchars(ENT_QUOTES, UTF-8)` recursivamente |
| **Validación estricta** | `Validation.php` | Clase con 11 validadores (name, email, phone, price, stock, id, doc, zip, password, address, numeric) y método `validateOrReject()` que corta ejecución con HTTP 400 |
| **Protección de archivos** | `.htaccess` | Bloquea acceso directo a `.env`, `.log`, `.sql`, `.bak`, `config.php`; deshabilita directory listing |
| **Validación de uploads** | `checkout.php` | Verificación triple: MIME real con `finfo`, extensión permitida, tamaño máximo 5MB |
| **Ofuscación de errores** | `config.php` | `display_errors=0`; errores registrados en log del servidor, nunca expuestos al cliente |

#### Capa 3: Base de Datos (PostgreSQL)

| Mecanismo | Detalle |
|-----------|---------|
| **Sentencias preparadas nativas** | `PDO::ATTR_EMULATE_PREPARES => false` fuerza prepared statements reales del motor, eliminando toda posibilidad de SQL injection |
| **Funciones opacas** | PHP ejecuta exclusivamente `SELECT fn_xxx(?)`. No hay SQL dinámico ni nombres de tablas en el código PHP |
| **Validaciones de negocio** | Cada función PL/pgSQL valida integridad antes de operar (duplicados, coherencia taxonómica, stock, propiedad) |
| **Anti-IDOR** | Funciones como `fn_user_get_orders(user_id)`, `fn_invoice_get_header(order, user)` filtran estrictamente por propietario |
| **Rate limiting en BD** | `tab_Rate_Limits` registra intentos fallidos por IP con ventana temporal configurable |
| **Lista blanca de estados** | `fn_orders_update_status` valida contra enum explícito: `('pendiente','confirmado','enviado','cancelado','entregado')` |
| **Protección de escalación** | `fn_admin_toggle_client` verifica que el target sea `rol='cliente'`, bloqueando modificación de cuentas admin |
| **Credenciales ocultas** | Archivo `.env` externo al webroot, parseado por `parse_ini_file()`, bloqueado por `.htaccess` |

### 3.2 Criptografía y Hashing

| Dato | Algoritmo | Implementación |
|------|-----------|---------------|
| **Contraseñas** | **bcrypt** (Blowfish, 60 chars) | PHP `password_hash($pass, PASSWORD_BCRYPT)` antes de enviar a la BD. Verificación con `password_verify()`. El hash nunca sale del servidor |
| **Migración legacy** | Detección automática | Si `password_verify` falla pero coincide en plano → se genera hash bcrypt y se actualiza vía `fn_auth_update_hash()` transparentemente |
| **Token de recuperación** | `bin2hex(random_bytes(32))` | Token de 64 caracteres con expiración de 1 hora, almacenado en BD vía `fn_auth_forgot_password()` |
| **Comparación de tokens** | `hash_equals()` | Comparación timing-safe para CSRF y tokens de recuperación |
| **Datos en tránsito** | TLS 1.2+ | Configurado a nivel de servidor web (cookie_secure preparado para producción) |

### 3.3 Prevención de Ataques

- **SQL Injection:** Eliminada por diseño. La combinación de `EMULATE_PREPARES=false` + funciones PL/pgSQL parametrizadas hace que sea matemáticamente imposible inyectar SQL desde el cliente.
- **XSS:** Mitigado en tres niveles: validación HTML5 en cliente, `sanitizeHtml()` en PHP, y CSP en headers.
- **CSRF:** Token validado en servidor con `hash_equals()` para toda operación mutante.
- **Brute Force:** Rate limiting basado en IP con `fn_sec_check_rate_limit()` (5 intentos / 15 minutos).
- **Session Fixation:** `session_regenerate_id(true)` tras login exitoso.
- **IDOR:** Filtrado por `user_id` de sesión en toda consulta de datos de usuario.
- **Directory Traversal:** `.htaccess` con `Options -Indexes` y bloqueo de archivos sensibles.

---

## 4. MOTOR DE BASE DE DATOS Y GESTIÓN DE TRANSACCIONES

### 4.1 Estándar de Conexión PHP ↔ PostgreSQL

**Driver:** PDO (PHP Data Objects) con driver `pgsql`.

**Gestión de credenciales:**
1. Las credenciales residen en `src/backend/.env` (excluido de Git vía `.gitignore`).
2. Si el archivo no existe, el sistema aborta con HTTP 500: `"Error Crítico: Archivo .env no detectado"`.
3. `parse_ini_file()` carga las variables; el DSN se construye dinámicamente con encoding UTF-8 forzado.

**Configuración de seguridad del driver:**
```php
$pdo = new PDO($dsn, $env['DB_USER'], $env['DB_PASS'], [
    PDO::ATTR_ERRMODE            => PDO::ERRMODE_EXCEPTION,  // Errores como excepciones
    PDO::ATTR_DEFAULT_FETCH_MODE => PDO::FETCH_ASSOC,        // Arrays asociativos
    PDO::ATTR_EMULATE_PREPARES   => false                    // Prepared statements REALES
]);
```

**Gestión de excepciones:** Todo endpoint envuelve la lógica en `try/catch(Throwable)`. Los errores se registran con `error_log()` y se responde con un mensaje genérico al cliente.

### 4.2 Ciclo de Vida de una Transacción y Propiedades ACID

PL/pgSQL garantiza las propiedades ACID de forma implícita:

- **Atomicidad:** Cada función PL/pgSQL se ejecuta dentro de una transacción implícita. Si cualquier sentencia lanza una excepción, PostgreSQL ejecuta un rollback automático de toda la función.
- **Consistencia:** Las validaciones de integridad (existencia de PK, coherencia de FK, validación de stock) se ejecutan ANTES de las operaciones DML, garantizando que la BD nunca quede en estado inconsistente.
- **Aislamiento:** PostgreSQL usa `READ COMMITTED` por defecto. Las funciones críticas (checkout, creación de IDs) emplean `LOCK TABLE ... IN EXCLUSIVE MODE` para serializar operaciones concurrentes.
- **Durabilidad:** PostgreSQL usa WAL (Write-Ahead Logging); los datos commiteados sobreviven a fallos del sistema.

### 4.3 Sistema de Auditoría Automática (Triggers)

El trigger `fun_audit_rdwatch()` se ejecuta en `BEFORE INSERT/UPDATE/DELETE` sobre **21 tablas**:

| Operación | Comportamiento |
|-----------|---------------|
| **INSERT** | Estampa `usr_insert = CURRENT_USER` y `fec_insert = CURRENT_TIMESTAMP` |
| **UPDATE** | Preserva los valores originales de insert; actualiza `usr_update` y `fec_update` |
| **DELETE** | **Intercepta y cancela** el DELETE físico. Convierte en soft-delete: actualiza campo de estado a `FALSE`, estampa `usr_delete` y `fec_delete`, y retorna `NULL` para cancelar la eliminación |

### 4.4 La Transacción Más Pesada: `fn_checkout_process`

Esta es la función más compleja y crítica del sistema. Convierte un carrito activo en una orden de compra completa, tocando **8 tablas en 10 pasos atómicos** dentro de una sola transacción.

#### Desglose Paso a Paso

```
ENTRADA: (user_id, dirección, ciudad, método_pago)
SALIDA:  JSON {ok, msg, order_id, payment_id}
```

| Paso | Operación | Tabla(s) | Tipo |
|------|-----------|----------|------|
| 1 | Localizar carrito activo del usuario | `tab_Carrito` | SELECT |
| 1.1 | Auto-completar dirección si vacía | `tab_Direcciones_Envio`, `tab_Ciudades`, `tab_Usuarios` | SELECT |
| 2-3 | Validar stock de CADA producto y calcular total | `tab_Carrito_Detalle` JOIN `tab_Productos` | SELECT + FOR LOOP |
| 4 | Crear orden (cabecera) | `tab_Orden` | LOCK + INSERT |
| 5 | Crear factura | `tab_Facturas` | LOCK + INSERT |
| 6 | Por cada ítem: crear detalle de orden + detalle de factura + descontar stock | `tab_Detalle_Orden`, `tab_Detalle_Factura`, `tab_Productos` | LOCK + INSERT + UPDATE (loop) |
| 7 | Gestionar dirección de envío (buscar existente o crear nueva) | `tab_Direcciones_Envio`, `tab_Ciudades` | SELECT + LOCK + INSERT |
| 8 | Crear registro de envío | `tab_Envios` | LOCK + INSERT |
| 9 | Crear registro de pago (sin comprobante) | `tab_Pagos` | LOCK + INSERT |
| 10 | Purgar carrito y marcar como convertido | `tab_Carrito_Detalle`, `tab_Carrito` | DELETE + UPDATE |

#### Garantías de Atomicidad

- Si el stock es insuficiente para **cualquier** producto → la función retorna `{ok: false}` y **ninguna** tabla se modifica.
- Si el total calculado es cero (carrito corrupto) → aborto inmediato.
- Si falla cualquier INSERT/UPDATE intermedio → PostgreSQL ejecuta rollback automático de toda la transacción.

#### Optimizaciones de Rendimiento

1. **Generación de IDs con LOCK:** Cada tabla usa `LOCK TABLE ... IN EXCLUSIVE MODE` + `COALESCE(MAX(id), 0) + 1` para generar PKs sin secuencias, serializando escrituras concurrentes.
2. **Doble iteración optimizada:** El primer loop (pasos 2-3) solo valida y calcula; el segundo loop (paso 6) solo escribe. Esto evita escrituras parciales si la validación falla a mitad del carrito.
3. **Comprobante diferido:** El archivo binario del comprobante de pago se inserta DESPUÉS de la función atómica mediante un `UPDATE tab_Pagos SET comprobante_ruta = ?`, porque PostgreSQL no maneja BYTEA como parámetro de función eficientemente. Este es el **único** SQL no-opaco del sistema, justificado por limitación técnica de LOB.

#### Flujo Completo desde el Cliente

```
[Cliente: Pulsa "Confirmar Compra"]
    → JS: secureFetch POST /checkout.php (FormData + comprobante)
        → PHP: requireLogin + validateCsrfToken
        → PHP: Validar inputs + archivo (MIME, extensión, 5MB max)
        → PHP: Mover archivo a disco → /comprobantes/
        → PHP: SELECT fn_checkout_process(user, dir, ciudad, método)
            → PG: 10 pasos atómicos → JSON {ok, order_id, payment_id}
        → PHP: UPDATE tab_Pagos SET comprobante_ruta (único SQL no-opaco)
        → PHP: echo JSON al cliente
    → JS: Muestra confirmación + redirect a factura
```

---

## ANEXO: MAPA DE ARCHIVOS DEL SISTEMA

```
RDWATCH/
├── index.html                          ← Landing Page (punto de entrada)
├── src/
│   ├── admin/
│   │   ├── admin.html                  ← Panel de administración
│   │   ├── admin.js                    ← Lógica CRUD admin (1755 líneas)
│   │   └── admin.css                   ← Estilos del panel admin
│   ├── user/
│   │   └── user.html                   ← Panel de cliente
│   ├── comercio.html                   ← Catálogo / Tienda
│   ├── factura.html                    ← Vista de factura
│   ├── css/
│   │   └── style.css                   ← Sistema de diseño global (82 KB)
│   ├── js/
│   │   ├── config.js                   ← Detección dinámica de API URL
│   │   ├── security.js                 ← secureFetch + CSRF
│   │   ├── notifications.js            ← Sistema de toasts
│   │   ├── script.js                   ← Lógica principal (82 KB)
│   │   └── stripe_checkout.js          ← Integración Stripe
│   └── backend/
│       ├── .env                        ← Credenciales (excluido de Git)
│       ├── .htaccess                   ← Protección de archivos sensibles
│       ├── config.php                  ← Bootstrap: sesiones, CORS, PDO, headers
│       ├── utils/
│       │   ├── security_utils.php      ← Auth guards, CSRF, sanitización
│       │   ├── Validation.php          ← 11 validadores + reject automático
│       │   └── mailer.php              ← PHPMailer para emails
│       └── api/ (29 endpoints)         ← Todas las rutas REST
├── sql/
│   ├── schema/
│   │   └── database_rdwatch_3_0.sql    ← DDL completo (tablas, constraints)
│   ├── logica_backend/ (5 módulos)
│   │   ├── auth_security.sql           ← 9 funciones de autenticación
│   │   ├── catalog_master.sql          ← 23 funciones de catálogo
│   │   ├── ecommerce_core.sql          ← 15 funciones de e-commerce
│   │   ├── client_panel.sql            ← 16 funciones de panel/reseñas
│   │   └── admin_reports.sql           ← 7 funciones de reportes
│   └── triggers/
│       └── audit_trail.sql             ← 21 triggers de auditoría automática
└── img/                                ← Assets visuales
```

---

*Fin del documento. Versión 1.0 — Abril 2026.*
