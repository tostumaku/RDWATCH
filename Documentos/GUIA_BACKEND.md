# 🛠️ Guía del Backend de RD WATCH V2

Esta guía explica la arquitectura técnica del proyecto, centrada en la **seguridad, modularidad y automatización**.

---

## 🏗️ 1. Infraestructura y Seguridad
El proyecto utiliza una pila tecnológica moderna basada en PHP y **PostgreSQL 16**.

| Elemento | Función |
| :--- | :--- |
| **Pila (Stack)** | PHP 8.x + PostgreSQL (en lugar de MySQL/MariaDB para mayor seguridad y robustez). |
| **`config.php`** | Conexión central vía **PDO**. Maneja sesiones, CORS y carga de entorno. |
| **`.env`** | Almacena credenciales de BD y claves de sesión de forma privada. |
| **BYTEA Storage** | Los comprobantes de pago no se guardan en carpetas públicas, sino como binarios protegidos directamente en la base de datos (columna `bytea`). Esto evita ataques de ejecución de scripts maliciosos. |
| **`get_comprobante.php`** | Endpoint seguro que extrae el binario, limpia el buffer de salida (`ob_clean`) para evitar corrupción y sirve la imagen con el MIME type correcto, validando permisos de admin. |

---

## 💾 2. Lógica de Base de Datos (Modular)
A diferencia de sistemas convencionales, la lógica de negocio reside en **Funciones de PostgreSQL** organizadas por módulos en `sql/functions/`:

- **`crud_usuarios.sql`**: Gestión de roles (Admin/Cliente), login y registro.
- **`crud_productos.sql`**: Control de inventario, marcas y categorías.
- **`crud_ordenes.sql`**: Procesamiento de transacciones y estados de pedido.
- **`crud_facturas.sql`**: Generación automática de facturación digital.

---

## 🔐 3. Flujo de Autenticación
- **`login.php`**: Valida credenciales contra la función `fun_login_usuario` y establece `$_SESSION['user_role']`.
- **`signup.php`**: Registra usuarios asegurando el hash de contraseña (BCRYPT).
- **`me.php`**: Sincroniza el estado de la sesión entre el servidor y el navegador.

---

## ⚙️ 4. Automatización (DevOps)
El proyecto incluye motores de instalación automática multiplataforma:

### Linux / Mac (`.sh`)
- **`install_db.sh`**: Script Bash que recrea la BD, carga el esquema, inyecta las funciones modulares y puebla el catálogo.
- Ejecución: `./install_db.sh`

### Windows (`.bat`)
- **`install_db.bat`**: Script Batch equivalente que configura el entorno, lee credenciales y ejecuta la secuencia SQL usando `psql`.
- Ejecución: Doble clic en el archivo o desde CMD.

- **Logs**: Todas las instalaciones se registran en `install_db.log` para auditoría.

---

## 🔄 Flujo de Datos (Workflow)
1. **Frontend**: El usuario realiza una acción (ej: Comprar).
2. **API (PHP)**: Recibe la petición y valida el usuario (`config.php`).
3. **Database (PL/pgSQL)**: El PHP llama a una función SQL (ej: `fun_crear_orden`). Esto garantiza que la lógica sea atómica y rápida.
4. **Respuesta**: El sistema devuelve JSON estándar al navegador.

---

> [!IMPORTANT]
> **Coherencia Proyectual**: Cualquier cambio en la base de datos debe realizarse primero en los archivos `.sql` de la carpeta `sql/` y luego aplicarse usando el script de instalación para mantener la integridad del sistema.
