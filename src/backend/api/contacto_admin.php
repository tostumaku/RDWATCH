<?php
/**
 * ============================================================
 * API: SOLICITUDES DE CONTACTO (VISTA ADMIN) (contacto_admin.php)
 * ============================================================
 * ENDPOINT: GET /api/contacto_admin.php
 *
 * PROPÓSITO:
 * Expone al administrador todas las solicitudes recibidas
 * desde el formulario de contacto de la página principal.
 * Llama a fn_contacto_list_admin() en PostgreSQL.
 * PHP nunca ve nombres de tablas ni columnas directamente.
 *
 * SEGURIDAD:
 * - Sesión obligatoria
 * - Solo rol 'admin' puede acceder
 * ============================================================
 */

header('Content-Type: application/json');
require_once '../config.php';
require_once '../utils/security_utils.php';

if (!isset($pdo)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error de configuración de BD']);
    exit;
}

// ──────────────────────────────────────────────
// SEGURIDAD: Sesión obligatoria + rol admin
// ──────────────────────────────────────────────
if (!isset($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['ok' => false, 'msg' => 'No autorizado: Inicie sesión para continuar']);
    exit;
}

if (($_SESSION['user_role'] ?? '') !== 'admin') {
    http_response_code(403);
    echo json_encode(['ok' => false, 'msg' => 'Acceso denegado: Solo administradores']);
    exit;
}

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['ok' => false, 'msg' => 'Método no permitido']);
    exit;
}

try {
    // Llamada opaca — PHP solo invoca la función, nunca toca la tabla directamente
    $stmt = $pdo->prepare("SELECT fn_contacto_list_admin()");
    $stmt->execute();

    $json = $stmt->fetchColumn() ?: '[]';
    echo '{"ok":true,"contactos":' . $json . '}';

} catch (Throwable $e) {
    http_response_code(500);
    error_log('[contacto_admin.php] ' . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.']);
}
