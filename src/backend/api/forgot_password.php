<?php
/**
 * ============================================================
 * API: SOLICITUD DE RECUPERACIÓN DE CONTRASEÑA (forgot_password.php)
 * ============================================================
 * ENDPOINT: POST /api/forgot_password.php
 *
 * PROPÓSITO:
 * El usuario olvidó su contraseña. Genera un token temporal
 * que se enviaría por email para permitir el reset.
 *
 * SEGURIDAD ANTI-ENUMERACIÓN:
 * Por diseño, SIEMPRE responde con el mismo mensaje genérico,
 * sin importar si el email existe o no. Esto previene que un
 * atacante pueda descubrir qué emails están registrados.
 *
 * FUNCIONES POSTGRESQL QUE USA:
 * - fn_auth_forgot_password(email, token, expiración) → JSON o NULL
 *   Internamente:
 *   1. Busca usuario activo por email
 *   2. Si existe: guarda token + expiración → retorna JSON con datos
 *   3. Si no existe: retorna NULL (PHP muestra mensaje genérico)
 *
 * FLUJO COMPLETO:
 * 1. Validar CSRF
 * 2. Validar formato del email
 * 3. Generar token criptográfico (64 caracteres hex)
 * 4. Definir expiración (+1 hora desde ahora)
 * 5. Llamar fn_auth_forgot_password
 * 6. SIEMPRE responder con mensaje genérico (anti-enumeración)
 * 7. Si el usuario existía: generar link de reset (en log del server)
 * ============================================================
 */

require_once '../config.php';
require_once '../utils/security_utils.php';
require_once '../utils/Validation.php';

header('Content-Type: application/json');

// PASO 1: Validar token CSRF (protección contra ataques CSRF)
validateCsrfToken(null, true);

// PASO 2: Obtener y validar el email del input
$input = getJsonInput();
Validation::validateOrReject($input, ['email' => 'email']);

$email = Validation::sanitizeString($input['email']);

try {
    // ──────────────────────────────────────────────
    // PASO 3: GENERAR TOKEN CRIPTOGRÁFICO
    // ──────────────────────────────────────────────
    // random_bytes(32) genera 32 bytes aleatorios criptográficamente seguros
    // bin2hex() los convierte en 64 caracteres hexadecimales (a-f, 0-9)
    // Ejemplo resultado: "a3f8c1d7e5b9...hasta 64 chars"
    // Este token se guardará en la BD y se usará en la URL de reset
    $token = bin2hex(random_bytes(32));

    // PASO 4: Definir cuándo expira el token (1 hora desde ahora)
    // strtotime('+1 hour') suma 1 hora al timestamp actual
    // date() lo formatea como YYYY-MM-DD HH:II:SS para PostgreSQL
    $expires = date('Y-m-d H:i:s', strtotime('+1 hour'));

    // ──────────────────────────────────────────────
    // PASO 5: REGISTRAR TOKEN EN BD (Consulta Opaca)
    // ──────────────────────────────────────────────
    // fn_auth_forgot_password:
    // - Si el email EXISTE y está activo → guarda token → retorna JSON con id y nombre
    // - Si el email NO EXISTE → no hace nada → retorna NULL
    // El "?::timestamp" le dice a PostgreSQL que trate el valor como tipo timestamp
    $stmt = $pdo->prepare("SELECT fn_auth_forgot_password(?, ?, ?::timestamp)");
    $stmt->execute([$email, $token, $expires]);
    $user = json_decode($stmt->fetchColumn(), true);

    // ──────────────────────────────────────────────
    // PASO 6: RESPONDER (SIEMPRE mensaje genérico)
    // ──────────────────────────────────────────────
    // IMPORTANTE: No importa si $user es NULL o tiene datos,
    // el mensaje al frontend es SIEMPRE el mismo.
    // Esto previene ataques de enumeración de usuarios.
    if (!$user) {
        // Email no encontrado → respuesta genérica (no revelamos que no existe)
        echo json_encode(["ok" => true, "msg" => "Si el correo está registrado, recibirás un enlace de recuperación en breve."]);
        exit;
    }

    // Email encontrado → generar link de reset
    require_once '../utils/mailer.php';

    // Obtener la URL base de forma dinámica
    $protocol = isset($_SERVER['HTTPS']) && $_SERVER['HTTPS'] === 'on' ? "https" : "http";
    $host = $_SERVER['HTTP_HOST'] ?? 'localhost';
    $scriptName = $_SERVER['SCRIPT_NAME'] ?? ''; 
    
    $pos = strpos($scriptName, '/src/backend/api/');
    $basePath = $pos !== false ? substr($scriptName, 0, $pos) : '';
    $appUrl = rtrim($protocol . '://' . $host . $basePath, '/');
    
    $resetLink = $appUrl . '/src/reset_password.html?token=' . $token;
    // ── Template HTML del correo ──────────────────────────────
    $nombreUsuario = htmlspecialchars($user['nom_usuario'] ?? 'Usuario');
    $htmlBody = "
    <!DOCTYPE html>
    <html lang='es'>
    <head><meta charset='UTF-8'></head>
    <body style='margin:0;padding:0;background:#f4f4f4;font-family:Montserrat,Arial,sans-serif;'>
      <table width='100%' cellpadding='0' cellspacing='0' style='background:#f4f4f4;padding:40px 0;'>
        <tr><td align='center'>
          <table width='560' cellpadding='0' cellspacing='0' style='background:#ffffff;border-radius:10px;overflow:hidden;box-shadow:0 4px 20px rgba(0,0,0,0.08);'>

            <!-- Header dorado -->
            <tr>
              <td style='background:#AF944F;padding:32px 40px;text-align:center;'>
                <h1 style='margin:0;color:#ffffff;font-size:22px;font-weight:700;letter-spacing:2px;text-transform:uppercase;'>
                  🕐 RD WATCH
                </h1>
              </td>
            </tr>

            <!-- Cuerpo -->
            <tr>
              <td style='padding:40px;color:#1A1A1A;'>
                <h2 style='margin:0 0 16px;font-size:20px;color:#0D0D0D;'>Recuperar contraseña</h2>
                <p style='margin:0 0 12px;font-size:15px;line-height:1.7;color:#444;'>
                  Hola <strong>{$nombreUsuario}</strong>,
                </p>
                <p style='margin:0 0 28px;font-size:15px;line-height:1.7;color:#444;'>
                  Recibimos una solicitud para restablecer la contraseña de tu cuenta.
                  Haz clic en el botón para crear una nueva contraseña:
                </p>

                <!-- Botón de acción -->
                <table width='100%' cellpadding='0' cellspacing='0'>
                  <tr>
                    <td align='center' style='padding:8px 0 32px;'>
                      <a href='{$resetLink}'
                         style='display:inline-block;background:#AF944F;color:#0D0D0D;text-decoration:none;
                                padding:14px 36px;border-radius:4px;font-weight:700;font-size:13px;
                                text-transform:uppercase;letter-spacing:2px;'>
                        Restablecer contraseña
                      </a>
                    </td>
                  </tr>
                </table>

                <p style='margin:0 0 8px;font-size:13px;color:#777;'>
                  Este enlace expira en <strong>1 hora</strong>.
                </p>
                <p style='margin:0 0 24px;font-size:13px;color:#777;'>
                  Si no solicitaste este cambio, puedes ignorar este correo — tu contraseña permanecerá igual.
                </p>

                <!-- Link de respaldo -->
                <p style='margin:0;font-size:12px;color:#999;border-top:1px solid #eee;padding-top:20px;'>
                  Si el botón no funciona, copia este enlace en tu navegador:<br>
                  <a href='{$resetLink}' style='color:#8E783F;word-break:break-all;'>{$resetLink}</a>
                </p>
              </td>
            </tr>

            <!-- Footer -->
            <tr>
              <td style='background:#f9f9f9;padding:20px 40px;text-align:center;border-top:1px solid #eee;'>
                <p style='margin:0;font-size:12px;color:#aaa;'>
                  © " . date('Y') . " RD Watch · Este es un correo automático, no respondas este mensaje.
                </p>
              </td>
            </tr>

          </table>
        </td></tr>
      </table>
    </body>
    </html>";

    $textBody = "Hola {$nombreUsuario},\n\nEnlace para restablecer tu contraseña:\n{$resetLink}\n\nEste enlace expira en 1 hora.\n\nSi no solicitaste este cambio, ignora este correo.";

    $emailEnviado = sendMail(
        to: $email,
        toName: $nombreUsuario,
        subject: '🕐 RD Watch — Recuperación de contraseña',
        htmlBody: $htmlBody,
        textBody: $textBody
    );

    if (!$emailEnviado) {
        // Si el email falla, el token sigue guardado en BD.
        // El admin puede recuperar el link desde el error_log del servidor.
        error_log("RESET LINK (email falló) for {$email}: {$resetLink}");
    }

    // MISMA respuesta genérica (protección anti-enumeración)
    echo json_encode([
        "ok"  => true,
        "msg" => "Si el correo está registrado, recibirás un enlace de recuperación en breve."
    ]);


}
catch (Throwable $e) {
    http_response_code(500);
    error_log('[forgot_password.php] ' . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Ha ocurrido un error inesperado al procesar la solicitud.']);
}
