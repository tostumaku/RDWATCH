<?php
/**
 * ============================================================
 * API: AUTENTICACIÓN GOOGLE OAUTH (auth_google.php)
 * ============================================================
 * ENDPOINT: POST /api/auth_google.php
 *
 * PROPÓSITO:
 * Recibe el JWT (Credential Token) generado por Google en el frontend,
 * lo valida matemáticamente usando la librería oficial de Google
 * para asegurar que no fue falsificado, y extrae los datos del usuario
 * para iniciar sesión o registrarlo en la base de datos local.
 * ============================================================
 */

require_once '../config.php';
require_once '../utils/Validation.php';

// Esta librería debe instalarse vía Composer en el servidor: composer require google/apiclient
require_once '../vendor/autoload.php'; 

header('Content-Type: application/json');

if ($_SERVER['REQUEST_METHOD'] !== 'POST') {
    http_response_code(405);
    echo json_encode(['ok' => false, 'msg' => 'Método no permitido']);
    exit;
}

$input = getJsonInput();
$credentialToken = $input['credential'] ?? '';

if (empty($credentialToken)) {
    http_response_code(400);
    echo json_encode(['ok' => false, 'msg' => 'Falta el token de credenciales de Google.']);
    exit;
}

// 1. Configurar el Cliente de Google
$envFile = __DIR__ . '/../.env';
$env = parse_ini_file($envFile);
$clientId = $env['GOOGLE_CLIENT_ID'] ?? '';

if (empty($clientId)) {
    http_response_code(500);
    error_log("[OAuth] Error: GOOGLE_CLIENT_ID no configurado en .env");
    echo json_encode(['ok' => false, 'msg' => 'La aplicación no está configurada correctamente para Google SignIn.']);
    exit;
}

$client = new Google_Client(['client_id' => $clientId]);

try {
    // 2. Verificar la firma del JWT (Falsificación o manipulación)
    $payload = $client->verifyIdToken($credentialToken);

    if ($payload) {
        $googleUserId = $payload['sub']; // ID Único universal de Google
        $email = $payload['email'];
        $name = $payload['name'];
        $emailVerified = $payload['email_verified'];

        if (!$emailVerified) {
            http_response_code(403);
            echo json_encode(['ok' => false, 'msg' => 'Google indica que este correo no está verificado.']);
            exit;
        }

        // 3. Ejecutar función de DB para iniciar sesión o vincular cuenta
        if (!isset($pdo)) {
            throw new Exception("Conexión PDO no disponible.");
        }

        $stmt = $pdo->prepare("SELECT fn_auth_oauth_login(?, ?, ?, ?)");
        $stmt->execute(['google', $googleUserId, $email, $name]);
        $resultJson = $stmt->fetchColumn();
        
        $userData = json_decode($resultJson, true);

        if (!$userData) {
            http_response_code(500);
            echo json_encode(['ok' => false, 'msg' => 'Error al registrar al usuario de Google en la base de datos.']);
            exit;
        }

        if ($userData['bloqueado']) {
            http_response_code(403);
            echo json_encode(['ok' => false, 'msg' => 'Tu cuenta ha sido bloqueada. Contacta soporte.']);
            exit;
        }
        
        if (!$userData['activo']) {
            http_response_code(403);
            echo json_encode(['ok' => false, 'msg' => 'Tu cuenta está inactiva. Contacta soporte.']);
            exit;
        }

        // 4. Iniciar la sesión local de PHP
        if (session_status() === PHP_SESSION_NONE) {
            session_start();
        }
        $_SESSION['user_id'] = $userData['id_usuario'];
        $_SESSION['user_name'] = $userData['nom_usuario'];
        $_SESSION['user_role'] = $userData['rol'];

        // 5. Responder con éxito
        echo json_encode([
            'ok' => true, 
            'msg' => 'Inicio de sesión con Google exitoso.',
            'data' => [
                'user_id' => $userData['id_usuario'],
                'user_name' => $userData['nom_usuario'],
                'role' => $userData['rol']
            ]
        ]);

    } else {
        http_response_code(401);
        echo json_encode(['ok' => false, 'msg' => 'Token de Google inválido o expirado.']);
    }
} catch (Exception $e) {
    http_response_code(500);
    error_log("[OAuth Google] Catch Error: " . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Error interno procesando el login de Google.']);
}
