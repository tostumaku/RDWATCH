<?php
/**
 * ============================================================
 * API: CIERRE DE SESIÓN SEGURO (logout.php)
 * ============================================================
 * ENDPOINT: POST /api/logout.php
 *
 * PROPÓSITO:
 * Finaliza la sesión del usuario de forma segura tanto en el
 * servidor como en el navegador del cliente.
 *
 * FLUJO DE SEGURIDAD:
 * 1. Validar token CSRF (previene logout forzado por CSRF)
 * 2. Limpiar $_SESSION en memoria
 * 3. Destruir sesión en el servidor
 * 4. Invalidar cookie PHPSESSID en el navegador
 *
 * NOTA: Este archivo NO toca la BD directamente.
 * No requiere migración a PostgreSQL, pero se documenta
 * exhaustivamente como parte del cierre del blindaje.
 * ============================================================
 */

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

require_once '../utils/security_utils.php';
validateCsrfToken(); // 🛡️ Bloqueo CSRF

// 1. Limpieza de datos en memoria del servidor
$_SESSION = array();

// 2. Destrucción física de la sesión
session_destroy();

/**
 * 3. SEGURIDAD DEL CLIENTE: LIMPIEZA DE COOKIE
 * Al expirar la cookie en el pasado, el navegador la elimina,
 * mitigando riesgos de Session Fixation o Hijacking.
 */
if (ini_get("session.use_cookies")) {
    $params = session_get_cookie_params();
    setcookie(
        session_name(),
        '',
        time() - 42000,
        $params["path"],
        $params["domain"],
        $params["secure"],
        $params["httponly"]
    );
}

echo json_encode([
    "ok" => true,
    "msg" => "Sesión cerrada de forma segura. Hasta pronto."
]);