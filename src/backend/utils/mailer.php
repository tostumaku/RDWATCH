<?php
/**
 * ============================================================
 * UTILIDAD DE ENVÍO DE CORREOS (mailer.php)
 * ============================================================
 * Wrapper sobre PHPMailer que usa Gmail SMTP.
 * Las credenciales se leen desde .env para no hardcodearlas.
 *
 * REQUISITO: PHPMailer instalado en el servidor.
 *   composer require phpmailer/phpmailer
 *   (ejecutar en c:\...\rdwatch\src\backend)
 *
 * USO:
 *   require_once '../utils/mailer.php';
 *   $ok = sendMail(
 *       to: 'destinatario@email.com',
 *       toName: 'Nombre Usuario',
 *       subject: 'Asunto del mensaje',
 *       htmlBody: '<p>Contenido HTML</p>',
 *       textBody: 'Contenido texto plano'
 *   );
 * ============================================================
 */

use PHPMailer\PHPMailer\PHPMailer;
use PHPMailer\PHPMailer\SMTP;
use PHPMailer\PHPMailer\Exception;

// Cargar PHPMailer (instalado con Composer)
$composerAutoload = dirname(__DIR__) . '/vendor/autoload.php';
if (!file_exists($composerAutoload)) {
    error_log('[mailer.php] PHPMailer no encontrado. Ejecuta: composer require phpmailer/phpmailer');
    function sendMail(string $to, string $toName, string $subject, string $htmlBody, string $textBody = ''): bool {
        error_log('[mailer.php] PHPMailer no instalado. Email NO enviado a: ' . $to);
        return false;
    }
    return;
}
require_once $composerAutoload;

/**
 * Envía un correo electrónico usando Gmail SMTP.
 *
 * @param string $to        Email del destinatario
 * @param string $toName    Nombre del destinatario
 * @param string $subject   Asunto del correo
 * @param string $htmlBody  Cuerpo HTML del correo
 * @param string $textBody  Cuerpo texto plano (fallback para clientes sin HTML)
 * @return bool             true si se envió correctamente, false si falló
 */
function sendMail(string $to, string $toName, string $subject, string $htmlBody, string $textBody = ''): bool {
    // ── Leer credenciales SMTP desde .env ──────────────────────
    $envFile = dirname(__DIR__) . '/.env';
    $env = [];
    if (file_exists($envFile)) {
        $env = parse_ini_file($envFile);
    }

    $smtpUser = $env['SMTP_USER']     ?? '';
    $smtpPass = $env['SMTP_PASS']     ?? '';
    $smtpFrom = $env['SMTP_FROM']     ?? $smtpUser;
    $smtpName = $env['SMTP_FROM_NAME'] ?? 'RD Watch';

    if (!$smtpUser || !$smtpPass) {
        error_log('[mailer.php] Credenciales SMTP no configuradas en .env (SMTP_USER, SMTP_PASS)');
        return false;
    }

    // ── Configurar PHPMailer ────────────────────────────────────
    $mail = new PHPMailer(true); // true = lanza excepciones en vez de retornar false

    try {
        // Servidor SMTP de Gmail
        $mail->isSMTP();
        $mail->Host       = 'smtp.gmail.com';
        $mail->SMTPAuth   = true;
        $mail->Username   = $smtpUser;
        $mail->Password   = $smtpPass;          // App Password de Google (16 chars)
        $mail->SMTPSecure = PHPMailer::ENCRYPTION_STARTTLS;
        $mail->Port       = 587;
        $mail->CharSet    = 'UTF-8';

        // Opcional: desactivar la verificación SSL en desarrollo
        // $mail->SMTPOptions = ['ssl' => ['verify_peer' => false]];

        // Remitente
        $mail->setFrom($smtpFrom, $smtpName);
        $mail->addReplyTo($smtpFrom, $smtpName);

        // Destinatario
        $mail->addAddress($to, $toName);

        // Contenido
        $mail->isHTML(true);
        $mail->Subject = $subject;
        $mail->Body    = $htmlBody;
        $mail->AltBody = $textBody ?: strip_tags($htmlBody); // Fallback automático si no hay texto plano

        $mail->send();
        error_log("[mailer.php] Email enviado correctamente a: {$to}");
        file_put_contents(__DIR__ . '/mail_debug.log', "[" . date('Y-m-d H:i:s') . "] SUCCESS sending to: {$to}\n", FILE_APPEND);
        return true;

    } catch (Exception $e) {
        error_log('[mailer.php] Error al enviar email a ' . $to . ': ' . $mail->ErrorInfo);
        file_put_contents(__DIR__ . '/mail_debug.log', "[" . date('Y-m-d H:i:s') . "] ERROR to {$to}: " . $mail->ErrorInfo . " | Exception: " . $e->getMessage() . "\n", FILE_APPEND);
        return false;
    }
}
