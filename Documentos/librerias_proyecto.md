# 📚 Librerías Externas del Proyecto RD_WATCH

Este documento explica en detalle las 4 librerías/servicios externos que utiliza el proyecto, cómo están integradas y para qué se usa cada una.

---

## 1. 🎨 Font Awesome 6.0.0-beta3

### ¿Qué es?
Es una librería de **iconografía vectorial** (SVG). En lugar de usar imágenes PNG para cada ícono, Font Awesome entrega íconos como fuentes de texto estilizadas, lo que los hace perfectamente nítidos en cualquier tamaño o resolución de pantalla.

### ¿Dónde se carga?
Se incluye una sola vez en el `<head>` del archivo principal `index.html`:

```html
<!-- index.html, línea 14 -->
<link rel="stylesheet"
    href="https://cdnjs.cloudflare.com/ajax/libs/font-awesome/6.0.0-beta3/css/all.min.css"
    integrity="sha384-5e2ESR8Ycmos6g3gAKr1Jvwye8sW4U1u/cAKulfVJnkakCcMqhOudbtPnvJ+nbv7"
    crossorigin="anonymous">
```

> Se carga desde **cdnjs.cloudflare.com** (CDN) en lugar de un archivo local para aprovechar la caché del navegador. Si el usuario ya visitó otro sitio que usó Font Awesome desde este CDN, el archivo ya está en su caché y no necesita descargarse de nuevo.

El atributo `integrity` es un **hash SHA-384** que actúa como firma digital: el navegador verifica que el archivo descargado no haya sido modificado (protección ante ataques de CDN comprometidos).

### ¿Cómo se usa?
Se utiliza únicamente en el HTML, aplicando clases CSS con el prefijo `fas` (solid), `far` (regular) o `fab` (brands) sobre etiquetas `<i>`:

```html
<!-- Ícono de reloj en el logo del header -->
<i class="fas fa-clock logo-icon"></i>

<!-- Ícono de carrito de compras (generado dinámicamente en script.js) -->
<button class="btn-add-cart">
    <i class="fas fa-cart-plus"></i> Añadir
</button>

<!-- Ícono del menú hamburguesa en móvil (se intercambia con fa-times al abrir) -->
<button class="mobile-menu-btn">
    <i class="fas fa-bars"></i>
</button>

<!-- Ícono del logo de Google en el botón de login social -->
<i class="fab fa-google"></i>
```

También se usa dinámicamente desde JavaScript cuando el menú móvil se abre o cierra:

```javascript
// script.js, línea 915
mobileMenuBtn.innerHTML = isActive
    ? '<i class="fas fa-times"></i>'   // ícono X cuando está abierto
    : '<i class="fas fa-bars"></i>';   // ícono hamburguesa cuando está cerrado
```

### ¿En qué partes del sitio aparece?
Está presente en absolutamente todos los archivos HTML del proyecto: `index.html`, `comercio.html`, `factura.html`, `src/admin/admin.html`, `src/user/user_panel.html`. Es la única fuente de íconos del sistema.

---

## 2. 🔤 Google Fonts (Playfair Display + Montserrat)

### ¿Qué es?
Es el servicio de fuentes tipográficas gratuitas de Google. Provee dos tipografías distintas con propósitos diferentes:
- **Playfair Display**: Tipografía serif (con remates), elegante y clásica. Usada para títulos y elementos de branding de alta relojería.
- **Montserrat**: Tipografía sans-serif (sin remates), moderna y legible. Usada para textos de cuerpo, formularios y elementos de interfaz.

### ¿Dónde se carga?
También se incluye en el `<head>` del HTML, **antes** de la hoja de estilos propia del proyecto para que las fuentes estén disponibles cuando se parsee el CSS:

```html
<!-- index.html, línea 11-13 -->
<link rel="stylesheet"
    href="https://fonts.googleapis.com/css2?family=Playfair+Display:wght@400;700&family=Montserrat:wght@300;400;600&display=swap"
    crossorigin="anonymous">
```

La URL le indica a Google qué fuentes y qué pesos (grosores) se necesitan:
- `Playfair+Display:wght@400;700` → peso normal y negrita
- `Montserrat:wght@300;400;600` → light, normal y semi-negrita
- `display=swap` → Mientras la fuente carga, el navegador muestra texto con una fuente del sistema (evita que el texto sea invisible durante la carga).

### ¿Cómo se usa?
Las fuentes se aplican en el archivo `src/css/style.css` mediante la propiedad `font-family`. No requiere ninguna llamada desde JavaScript. Google Fonts inyecta la regla `@font-face` que le dice al navegador dónde descargar los archivos `.woff2`.

El uso típico en el CSS es:
```css
/* Títulos de secciones, hero, branding */
font-family: 'Playfair Display', Georgia, serif;

/* Textos de interfaz, botones, formularios */
font-family: 'Montserrat', Arial, sans-serif;
```

### ¿Por qué dos fuentes distintas?
Es una técnica estándar en diseño web premium llamada **pairing de tipografías**. La combinación de una serif elegante para títulos y una sans-serif limpia para el cuerpo crea contraste visual que refuerza la identidad de lujo del proyecto sin sacrificar la legibilidad en textos largos.

---

## 3. 🔐 Google Identity Services (GSI)

### ¿Qué es?
Es la librería oficial de Google para implementar **"Iniciar sesión con Google"** (OAuth 2.0). Permite que los usuarios autentiquen su identidad con su cuenta de Google sin necesidad de crear una contraseña en el sistema.

### ¿Dónde se carga?
Se declara en el `<head>` de `index.html` como script externo con los atributos `async` y `defer` para no bloquear la carga de la página:

```html
<!-- index.html, línea 19-20 -->
<!-- Google Identity Services -->
<script src="https://accounts.google.com/gsi/client" async defer></script>
```

Adicionalmente, `script.js` incluye una verificación de seguridad por si la librería no estaba ya cargada, y la añade dinámicamente:

```javascript
// script.js, línea 836-842
if (!document.querySelector('script[src="https://accounts.google.com/gsi/client"]')) {
    const script = document.createElement('script');
    script.src = "https://accounts.google.com/gsi/client";
    script.async = true;
    script.defer = true;
    document.head.appendChild(script);
}
```

### ¿Cómo funciona? (Flujo completo)

**1. Inicialización:**
Cuando el DOM termina de cargarse, la función `initGoogleAuth()` espera (con polling cada 100ms) a que la librería de Google esté disponible y luego la configura con el `client_id` del proyecto en Google Cloud Console:

```javascript
// script.js, línea 880-883
google.accounts.id.initialize({
    client_id: '161765677969-t8kq1e2g5ol447aef763p5likq0enqed.apps.googleusercontent.com',
    callback: handleGoogleCallback  // función que se ejecuta cuando el usuario confirma
});
```

**2. Renderizado del botón:**
Google reemplaza los botones HTML estáticos (`#googleLogin`, `#googleSignup`) con su propio botón oficial con el logo de Google:

```javascript
// script.js, línea 885-896
['googleLogin', 'googleSignup'].forEach(id => {
    const btn = document.getElementById(id);
    const container = document.createElement('div');
    btn.parentElement.insertBefore(container, btn);
    google.accounts.id.renderButton(container, {
        theme: 'outline', size: 'large', type: 'icon', shape: 'circle'
    });
    btn.style.display = 'none'; // Oculta el botón HTML original
});
```

**3. Autenticación del usuario:**
Cuando el usuario hace clic en el botón de Google y acepta, Google ejecuta el callback `handleGoogleCallback` entregando un **JWT (JSON Web Token)** llamado `credential`:

```javascript
// script.js, línea 844-871
window.handleGoogleCallback = async function(response) {
    if (!response.credential) return;

    // El credential es un JWT con la información verificada del usuario
    const res = await secureFetch(`${API_CONFIG.baseUrl}/auth_google.php`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ credential: response.credential })
    });

    const data = await res.json();
    if (data.ok) {
        sessionStorage.setItem('user_logged_in', 'true');
        // Redirige al panel de admin o recarga la página según el rol
        if (data.data.role === 'admin') {
            window.location.href = '...admin/admin.html';
        } else {
            window.location.reload();
        }
    }
};
```

**4. Verificación en PHP:**
El archivo `src/backend/api/auth_google.php` recibe el JWT, lo verifica llamando a la API de Google para confirmar que es auténtico (no falsificado), extrae el email, nombre y foto del usuario, y llama a las funciones PostgreSQL para registrar o identificar al usuario en `tab_Usuarios`.

### ¿Por qué se usa OAuth y no contraseña directa?
- **Seguridad**: El sistema nunca toca ni almacena la contraseña de Google del usuario.
- **UX**: El usuario no necesita recordar otra contraseña.
- **Confianza**: Google ya verificó la identidad y el email del usuario.

---

## 4. 📧 PHPMailer (v7.0)

### ¿Qué es?
Es la librería estándar de la industria para **envío de correos electrónicos desde PHP**. Reemplaza la función nativa `mail()` de PHP que es básica, insegura y cuyo resultado casi siempre termina en SPAM. PHPMailer permite conectarse a servidores SMTP reales (como Gmail) con autenticación, encriptación TLS y correos en formato HTML.

### ¿Cómo se instaló?
Se instaló mediante **Composer** (el gestor de dependencias de PHP), declarado en `src/backend/composer.json`:

```json
{
    "require": {
        "phpmailer/phpmailer": "^7.0"
    }
}
```

Los archivos de la librería se encuentran en `src/backend/vendor/phpmailer/phpmailer/`.

### ¿Dónde se centraliza su uso?
Toda la configuración y la lógica de envío se encapsula en un único archivo utilitario:

**`src/backend/utils/mailer.php`**

Este archivo actúa como un "wrapper" que:
1. Carga el autoloader de Composer para importar PHPMailer.
2. Lee las credenciales SMTP del archivo `.env` (nunca hardcodeadas en el código).
3. Expone una única función pública `sendMail()` para que el resto del backend la use sin saber los detalles internos.

```php
// mailer.php — configuración interna de PHPMailer
$mail = new PHPMailer(true);
$mail->isSMTP();
$mail->Host       = 'smtp.gmail.com';
$mail->SMTPAuth   = true;
$mail->Username   = $smtpUser;          // Leído de .env: SMTP_USER
$mail->Password   = $smtpPass;          // Leído de .env: SMTP_PASS (App Password de Google)
$mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
$mail->Port       = 587;                // Puerto estándar TLS de Gmail
$mail->CharSet    = 'UTF-8';
```

### ¿Dónde se invoca `sendMail()`?

Actualmente **un único endpoint** lo utiliza:

**`src/backend/api/forgot_password.php`** — Recuperación de contraseña

El flujo completo es el siguiente:

**Paso 1 (PHP):** Se genera un token criptográfico seguro de 64 caracteres:
```php
$token = bin2hex(random_bytes(32));  // 32 bytes = 64 hex chars
$expires = date('Y-m-d H:i:s', strtotime('+1 hour'));
```

**Paso 2 (PostgreSQL):** El token se guarda en la BD junto al usuario:
```php
$stmt = $pdo->prepare("SELECT fn_auth_forgot_password(?, ?, ?::timestamp)");
$stmt->execute([$email, $token, $expires]);
```

**Paso 3 (PHP + PHPMailer):** Si el usuario existe, se construye un correo HTML con los colores dorados del branding del proyecto y se envía:
```php
// forgot_password.php, línea 179-185
$emailEnviado = sendMail(
    to:       $email,
    toName:   $nombreUsuario,
    subject:  '🕐 RD Watch — Recuperación de contraseña',
    htmlBody: $htmlBody,   // Email HTML completo con botón dorado y logo
    textBody: $textBody    // Versión texto plano como fallback
);
```

El correo resultante contiene un botón "Restablecer contraseña" que lleva al usuario a `src/reset_password.html?token=...` con el token incrustado en la URL.

### Seguridad anti-enumeración
El endpoint **siempre responde con el mismo mensaje** al frontend, sin importar si el email existe o no. Esto evita que un atacante pueda usar el formulario para averiguar qué emails están registrados en el sistema:

```php
// forgot_password.php, línea 194-197
echo json_encode([
    "ok"  => true,
    "msg" => "Si el correo está registrado, recibirás un enlace de recuperación en breve."
]);
```

### Configuración requerida (.env)
Para que funcione, el archivo `src/backend/.env` debe tener estas variables:
```env
SMTP_USER=rdwatchcontacto@gmail.com
SMTP_PASS=xxxx xxxx xxxx xxxx   # App Password de 16 chars de Google
SMTP_FROM=rdwatchcontacto@gmail.com
SMTP_FROM_NAME=RD Watch
```

> **Nota:** Se usa una "Contraseña de Aplicación" de Google (App Password) y no la contraseña real de Gmail, porque Google bloquea el acceso SMTP directo con la contraseña normal por seguridad.

---

## 📊 Resumen comparativo

| Librería | Tipo | Se carga en | Se usa desde | Propósito |
|---|---|---|---|---|
| **Font Awesome** | CSS/Fuente | HTML `<head>` | HTML + JS dinámico | Iconografía del sitio completo |
| **Google Fonts** | CSS | HTML `<head>` | CSS (`style.css`) | Tipografías Playfair Display y Montserrat |
| **Google Identity Services** | JavaScript | HTML `<head>` + JS dinámico | `script.js` → `auth_google.php` | Login/Registro social con cuenta Google |
| **PHPMailer** | PHP (Composer) | `utils/mailer.php` | `forgot_password.php` | Envío de correo SMTP para recuperar contraseña |
