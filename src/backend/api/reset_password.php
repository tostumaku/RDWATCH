<?php
/**
 * ============================================================
 * API: RESETEAR CONTRASEÑA CON TOKEN (reset_password.php)
 * ============================================================
 * ENDPOINT: POST /api/reset_password.php
 *
 * PROPÓSITO:
 * El usuario recibió un enlace de recuperación con un token.
 * Este endpoint recibe el token + nueva contraseña y la aplica.
 *
 * FUNCIONES POSTGRESQL QUE USA:
 * - fn_auth_reset_password(token, hash) → JSON
 *   Internamente:
 *   1. Busca un usuario cuyo token coincida Y no haya expirado
 *   2. Si lo encuentra: actualiza contraseña, limpia token → {ok: true}
 *   3. Si no: retorna {ok: false} (token inválido o expirado)
 *
 * FLUJO COMPLETO:
 * 1. Validar CSRF
 * 2. Obtener token y nueva contraseña del input
 * 3. Validar complejidad de la nueva contraseña
 * 4. Generar hash bcrypt de la nueva contraseña
 * 5. Llamar fn_auth_reset_password
 * 6. Reenviar respuesta JSON al frontend
 * ============================================================
 */

require_once '../config.php';
require_once '../utils/security_utils.php';
require_once '../utils/Validation.php';

header('Content-Type: application/json');

// PASO 1: Validar token CSRF
validateCsrfToken(null, true);

// PASO 2: Obtener datos del input
$input = getJsonInput();
$token = $input['token'] ?? ''; // Token de 64 caracteres hex (de la URL)
$newPassword = $input['password'] ?? ''; // Nueva contraseña en texto plano

// PASO 3: Validar que ambos campos estén presentes
if (!$token || !$newPassword) {
    echo json_encode(["ok" => false, "msg" => "Datos faltantes: Se requiere token y nueva contraseña"]);
    exit;
}

// Validar complejidad de la nueva contraseña (mínimo 6 chars, mixto)
Validation::validateOrReject(['password' => $newPassword], ['password' => 'password']);

try {
    // ──────────────────────────────────────────────
    // PASO 4: GENERAR HASH BCRYPT DE LA NUEVA CONTRASEÑA
    // ──────────────────────────────────────────────
    // Igual que en login.php y signup.php, NUNCA enviamos
    // la contraseña en texto plano a PostgreSQL
    $hash = password_hash($newPassword, PASSWORD_BCRYPT);

    // ──────────────────────────────────────────────
    // PASO 5: APLICAR NUEVA CONTRASEÑA (Consulta Opaca)
    // ──────────────────────────────────────────────
    // fn_auth_reset_password internamente:
    // - Busca usuario con este token + token no expirado
    // - Si existe: actualiza contraseña, limpia token
    // - Si no existe: retorna error
    // PHP no sabe NADA de la tabla ni los campos
    $stmt = $pdo->prepare("SELECT fn_auth_reset_password(?, ?)");
    $stmt->execute([$token, $hash]);

    // PASO 6: Decodificar y reenviar respuesta
    // La respuesta viene pre-formateada desde PostgreSQL
    $result = json_decode($stmt->fetchColumn(), true);
    echo json_encode($result);

}
catch (Throwable $e) {
    http_response_code(500);
    error_log('[reset_password.php] ' . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Ha ocurrido un error inesperado al procesar la solicitud.']);
}
