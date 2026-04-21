<?php
/**
 * ============================================================
 * API: CONTACTO GENERAL (contacto.php)
 * ============================================================
 * ENDPOINT: POST /api/contacto.php
 *
 * PROPÓSITO:
 * Maneja las solicitudes de contacto desde la página principal.
 * Inserta el mensaje en `tab_Contacto`, no requiere inicio de sesión.
 *
 * SEGURIDAD:
 * - Rate limiting para evitar el spam (5 intentos por hora).
 * - CSRF obligatorio
 * - Validación y sanitización estricta
 * ============================================================
 */

header('Content-Type: application/json');
require_once '../config.php';
require_once '../utils/Validation.php';
require_once '../utils/security_utils.php';

// Solo POST permitido

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['ok' => false, 'msg' => 'Método no permitido']);
    exit;
}

if (!isset($pdo)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error de configuración de BD']);
    exit;
}

// CSRF obligatorio
validateCsrfToken(null, true);

$data = getJsonInput();

$clientIP = getClientIP();

// ──────────────────────────────────────────────
// RATE LIMITING DE MENSAJES DE CONTACTO
// ──────────────────────────────────────────────
try {
    $rlStmt = $pdo->prepare("SELECT fn_sec_check_rate_limit(?, ?, 5, 60)");
    $rlStmt->execute([$clientIP, 'contact_form_submission']);
    if (!$rlStmt->fetchColumn()) {
        http_response_code(429);
        echo json_encode(["ok" => false, "msg" => "Has enviado muchos mensajes en poco tiempo. Por favor intenta más tarde."]);
        exit;
    }

    // Registrar intento
    $pdo->prepare("SELECT fn_sec_log_attempt(?, ?)")->execute([$clientIP, 'contact_form_submission']);
} catch (PDOException $rlErr) {
    // El rate limiting no debe bloquear el formulario si hay un error de BD en esa lógica
    error_log("Rate limit warning en contacto.php: " . $rlErr->getMessage());
}

try {
    // ──────────────────────────────────────────────
    // VALIDACIÓN DE INPUTS
    // ──────────────────────────────────────────────
    Validation::validateOrReject($data, [
        'nombre' => 'name',
        'email' => 'email',
        // 'telefono' se validará manualmente abajo
        // 'mensaje' requiere más de 100 caracteres (la regla name lo limita)
    ]);

    $nombre = Validation::sanitizeString($data['nombre']);
    $email = Validation::sanitizeString($data['email']);
    $telefonoRaw = Validation::sanitizeString($data['telefono'] ?? '');
    $telefono = preg_replace('/\D/', '', $telefonoRaw); // Solo dígitos
    $mensaje = Validation::sanitizeString($data['mensaje'] ?? '');

    if (empty($mensaje)) {
        http_response_code(400);
        echo json_encode(['ok' => false, 'msg' => 'El mensaje es obligatorio']);
        exit;
    }

    // Validar teléfono: exactamente 10 dígitos
    if (strlen($telefono) !== 10) {
        echo json_encode(['ok' => false, 'msg' => 'El teléfono debe tener exactamente 10 dígitos']);
        exit;
    }

    // ──────────────────────────────────────────────
    // INSERTAR EL MENSAJE EN TAB_CONTACTO
    // ──────────────────────────────────────────────

    $stmt = $pdo->prepare("SELECT fn_contacto_public_create(?, ?, ?::BIGINT, ?)");
    $stmt->execute([$nombre, $email, $telefono, $mensaje]);

    // Devolvemos el JSON exacto que PostgreSQL nos retorna de forma segura
    echo json_encode(json_decode($stmt->fetchColumn(), true));

}
catch (PDOException $e) {
    http_response_code(500);
    error_log('[contacto.php] ' . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.']);
}
