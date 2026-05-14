<?php
/**
 * ENDPOINT TEMPORAL DE DEBUG - REMOVE EN PRODUCCIÓN
 * Prueba paso a paso el flujo de login
 */

require_once '../config.php';
require_once '../utils/security_utils.php';
require_once '../utils/Validation.php';

header('Content-Type: application/json');

$debug = [
    'paso' => 0,
    'errores' => [],
    'datos' => []
];

try {
    $debug['paso'] = 1;
    $debug['datos']['pdo_status'] = $pdo ? 'Conectado' : 'Sin conexión';

    // Probar que la sesión existe
    $debug['paso'] = 2;
    if (session_status() === PHP_SESSION_NONE) {
        session_start();
    }
    $debug['datos']['session_status'] = 'Sesión iniciada';

    // Obtener datos
    $input = getJsonInput();
    $debug['paso'] = 3;
    $debug['datos']['email'] = $input['email'] ?? 'NO RECIBIDO';

    // Probar rate limit
    $debug['paso'] = 4;
    $clientIP = getClientIP();
    $debug['datos']['client_ip'] = $clientIP;

    try {
        $rlStmt = $pdo->prepare("SELECT fn_sec_check_rate_limit(?, ?, 5, 15)");
        $rlStmt->execute([$clientIP, 'login_attempt']);
        $rlResult = $rlStmt->fetchColumn();
        $debug['datos']['rate_limit_result'] = $rlResult ? 'Permitido' : 'Bloqueado';
    } catch (Exception $e) {
        $debug['errores'][] = 'Rate limit error: ' . $e->getMessage();
    }

    // Probar obtener usuario
    $debug['paso'] = 5;
    $email = Validation::sanitizeString($input['email'] ?? '');
    try {
        $stmt = $pdo->prepare("SELECT fn_auth_get_user(?)");
        $stmt->execute([$email]);
        $userJson = $stmt->fetchColumn();
        $user = json_decode($userJson, true);
        $debug['datos']['user_found'] = $user ? 'Sí' : 'No';
        if ($user) {
            $debug['datos']['user_name'] = $user['nom_usuario'] ?? 'Sin nombre';
            $debug['datos']['user_active'] = $user['activo'] ?? 'Unknown';
        }
    } catch (Exception $e) {
        $debug['errores'][] = 'Auth get user error: ' . $e->getMessage();
    }

    $debug['paso'] = 'COMPLETADO';

} catch (Throwable $e) {
    $debug['errores'][] = 'FATAL: ' . $e->getMessage();
    $debug['trace'] = $e->getTraceAsString();
}

http_response_code(200);
echo json_encode($debug, JSON_PRETTY_PRINT | JSON_UNESCAPED_UNICODE);
