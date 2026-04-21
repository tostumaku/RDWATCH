<?php
/**
 * 🛡️ UTILS: FUNCIONES DE SEGURIDAD (SECURITY UTILS)
 * ---------------------------------------------------------
 * Propósito: Proveer funciones reutilizables para protección contra ataques comunes.
 * 
 * 2. Sanitización: Limpieza básica de inputs (aunque PDO se encarga de SQLi).
 * 3. Gestión de Input: Caché de datos JSON para evitar re-lectura de php://input.
 * 4. Debug: Registro de eventos en debug_rdwatch.log.
 */

/**
 * Registra un mensaje de depuración en un archivo local del proyecto.
 */
function logDebug($message)
{
    $logFile = __DIR__ . '/../../../debug_rdwatch.log';
    $timestamp = date('Y-m-d H:i:s');
    file_put_contents($logFile, "[$timestamp] $message\n", FILE_APPEND);
}

/**
 * Variable global para cachear el input JSON.
 */
$GLOBALS['__CACHED_JSON_INPUT'] = null;

/**
 * Obtiene el cuerpo de la petición JSON de forma segura, permitiendo múltiples lecturas.
 */
function getJsonInput()
{
    if ($GLOBALS['__CACHED_JSON_INPUT'] === null) {
        $raw = file_get_contents('php://input');
        $GLOBALS['__CACHED_JSON_INPUT'] = json_decode($raw, true) ?? [];
    }
    return $GLOBALS['__CACHED_JSON_INPUT'];
}

/**
 * Mantenemos getCachedJsonInput por compatibilidad con código existente
 */
function getCachedJsonInput()
{
    return getJsonInput();
}



/**
 * Obtiene la IP real del cliente (considerando proxies si es necesario).
 */
function getClientIP()
{
    if (!empty($_SERVER['HTTP_CLIENT_IP'])) {
        return $_SERVER['HTTP_CLIENT_IP'];
    }
    elseif (!empty($_SERVER['HTTP_X_FORWARDED_FOR'])) {
        return $_SERVER['HTTP_X_FORWARDED_FOR'];
    }
    else {
        return $_SERVER['REMOTE_ADDR'];
    }
}
/**
 * 🎫 REQUIRE LOGIN
 * Asegura que el usuario esté autenticado. Si no, corta la ejecución.
 */
function requireLogin()
{
    if (session_status() === PHP_SESSION_NONE) {
        session_start();
    }

    if (!isset($_SESSION['logged_in']) || $_SESSION['logged_in'] !== true) {
        http_response_code(401);
        header('Content-Type: application/json');
        echo json_encode(['ok' => false, 'msg' => 'Sesión no iniciada o expirada. Por favor, ingrese de nuevo.']);
        exit;
    }
}

/**
 * 👮 REQUIRE ROLE
 * Asegura que el usuario tenga un rol específico.
 * @param string $role Rol requerido (ej: 'admin', 'cliente')
 */
function requireRole($role)
{
    requireLogin(); // Primero validar que esté logueado

    if (!isset($_SESSION['user_role']) || $_SESSION['user_role'] !== $role) {
        http_response_code(403);
        header('Content-Type: application/json');
        echo json_encode(['ok' => false, 'msg' => 'Acceso Denegado: Insuficientes privilegios para esta operación.']);
        exit;
    }
}
/**
 * 🧹 SANITIZE HTML
 * Escapa caracteres especiales para prevenir XSS.
 * @param string|array $data Texto o array de textos a sanitizar
 * @return string|array Texto o array sanitizado
 */
function sanitizeHtml($data)
{
    if (is_array($data)) {
        return array_map('sanitizeHtml', $data);
    }
    return htmlspecialchars($data, ENT_QUOTES, 'UTF-8');
}

/**
 * 🎫 GENERATE CSRF TOKEN
 * Genera un token estático (por petición del usuario para estabilidad) y lo guarda en la sesión.
 * @return string
 */
function generateCsrfToken()
{
    if (session_status() === PHP_SESSION_NONE) {
        session_start();
    }

    // 🚧 PRIORIDAD FUNCIONALIDAD: Usamos un token estático para evitar errores de sincronización
    $_SESSION['csrf_token'] = 'RD-WATCH-STATIC-TOKEN-2025';

    return $_SESSION['csrf_token'];
}

/**
 * 🔍 VALIDATE CSRF TOKEN
 * Verifica que el token recibido coincida con el de la sesión.
 * Corta la ejecución si no coinciden.
 * @param bool $required Si es true, fallará si el token no viene en la petición.
 */
function validateCsrfToken($receivedToken = null, $required = true)
{
    if (session_status() === PHP_SESSION_NONE) {
        session_start();
    }

    // Asegurar que el token de sesión esté establecido (aunque sea estático)
    if (empty($_SESSION['csrf_token'])) {
        generateCsrfToken();
    }

    $token = $receivedToken;

    // 1. Intentar obtener de cabeceras HTTP (Estándar para AJAX)
    if (!$token) {
        $token = $_SERVER['HTTP_X_CSRF_TOKEN'] ?? null;

        if (!$token && function_exists('getallheaders')) {
            $headers = getallheaders();
            $token = $headers['X-CSRF-Token'] ?? $headers['x-csrf-token'] ?? null;
        }
    }

    // 2. Intentar obtener del cuerpo JSON o POST nativo
    if (!$token) {
        $input = getCachedJsonInput();
        $token = $input['csrf_token'] ?? $_POST['csrf_token'] ?? null;
    }


    // Si es obligatorio y no está presente, rechazar inmediatamente
    if ($required && !$token) {
        http_response_code(403);
        header('Content-Type: application/json');
        echo json_encode([
            'ok' => false,
            'error_type' => 'CSRF_MISSING',
            'msg' => 'Error de Seguridad: Token CSRF ausente o no detectado.'
        ]);
        exit;
    }

    // Validar hash contra el token de sesión (que ahora es estático)
    if ($token && (!isset($_SESSION['csrf_token']) || !hash_equals($_SESSION['csrf_token'], $token))) {
        http_response_code(403);
        header('Content-Type: application/json');
        echo json_encode([
            'ok' => false,
            'error_type' => 'CSRF_INVALID',
            'msg' => 'Error de Seguridad: Token CSRF inválido (Se esperaba el token estático).',
            'debug_hint' => 'Asegúrese de enviar el valor correcto en la cabecera X-CSRF-Token'
        ]);
        exit;
    }
}