<?php
/**
 * ============================================================
 * API: AJUSTES GLOBALES DEL SITIO (admin_settings.php)
 * ============================================================
 * ENDPOINTS:
 *   GET  /api/admin_settings.php                      → Obtener configuración
 *   POST /api/admin_settings.php?action=update_store  → Guardar nombre y moneda de tienda
 *   POST /api/admin_settings.php?action=update_admin  → Cambiar contraseña del admin
 *
 * PROPÓSITO:
 * Centraliza los parámetros configurables de la plataforma y el
 * cambio de contraseña del administrador.
 *
 * ACCESO: SOLO ADMIN (requireRole('admin'))
 *
 * FUNCIONES POSTGRESQL QUE USA:
 * - fn_admin_get_settings()              → JSON {store, admin}
 * - fn_admin_update_settings(json)       → JSON {ok, msg}
 * - fn_admin_get_hash(id)               → TEXT (hash bcrypt actual)
 * - fn_admin_set_password(id, hash)     → JSON {ok, msg}
 * ============================================================
 */

header('Content-Type: application/json');
require_once '../config.php';
require_once '../utils/security_utils.php';

if (!isset($pdo)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error técnico: La conexión a la base de datos no está disponible']);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'];
$action = $_GET['action'] ?? '';

try {
    switch ($method) {

        case 'GET':
            // ══════════════════════════════════════
            // 🔍 OBTENER CONFIGURACIÓN
            // ══════════════════════════════════════
            $stmt = $pdo->prepare("SELECT fn_admin_get_settings()");
            $stmt->execute();
            $settings = json_decode($stmt->fetchColumn(), true);

            echo json_encode([
                'ok'    => true,
                'store' => $settings['store'] ?? ['nombre' => 'RD-Watch', 'moneda' => 'COP'],
                'admin' => $settings['admin'] ?? ['usuario' => 'admin']
            ]);
            break;

        case 'POST':
        case 'PUT':
            // ══════════════════════════════════════
            // 🔄 ACTUALIZAR SEGÚN ACCIÓN
            // ══════════════════════════════════════
            // 🛡️ Solo admins pueden modificar la configuración
            requireRole('admin');
            validateCsrfToken(null, true);
            $data = getJsonInput();

            if ($action === 'update_config') {
                // ── Formulario unificado: usuario + moneda + contraseña ──
                $currentPass = trim($data['current_pass'] ?? '');
                $newPass     = trim($data['new_pass'] ?? '');
                $usuario     = trim($data['usuario'] ?? '');
                $moneda      = trim($data['moneda'] ?? '');
                $tasaCambio  = isset($data['tasa_cambio']) ? (float)$data['tasa_cambio'] : null;

                if (!$currentPass) {
                    echo json_encode(['ok' => false, 'msg' => 'Debes ingresar tu contraseña actual para confirmar cambios']);
                    exit;
                }

                if ($newPass && strlen($newPass) < 8) {
                    echo json_encode(['ok' => false, 'msg' => 'La nueva contraseña debe tener al menos 8 caracteres']);
                    exit;
                }

                $adminId = $_SESSION['user_id'] ?? null;
                if (!$adminId) {
                    http_response_code(401);
                    echo json_encode(['ok' => false, 'msg' => 'Sesión no válida']);
                    exit;
                }

                // Verificar contraseña actual
                $stmtHash = $pdo->prepare("SELECT fn_admin_get_hash(?)");
                $stmtHash->execute([$adminId]);
                $hashActual = $stmtHash->fetchColumn();

                if (!$hashActual || !password_verify($currentPass, $hashActual)) {
                    echo json_encode(['ok' => false, 'msg' => 'La contraseña actual es incorrecta']);
                    exit;
                }

                $mensajes = [];

                // Actualizar nombre de usuario
                if ($usuario !== '') {
                    $stmtNombre = $pdo->prepare("SELECT fn_admin_update_nombre(?, ?)");
                    $stmtNombre->execute([$adminId, $usuario]);
                    $resNombre = json_decode($stmtNombre->fetchColumn(), true);
                    if (!$resNombre['ok']) { echo json_encode($resNombre); exit; }
                    $mensajes[] = 'Usuario actualizado';
                }

                // Actualizar moneda y tasa de cambio en tab_Configuracion
                if ($moneda !== '') {
                    $stmtMoneda = $pdo->prepare("SELECT fn_admin_update_settings(?::json)");
                    $stmtMoneda->execute([json_encode(['moneda' => $moneda, 'tasa_cambio' => $tasaCambio])]);
                    $resMoneda = json_decode($stmtMoneda->fetchColumn(), true);
                    if (!$resMoneda['ok']) { echo json_encode($resMoneda); exit; }
                    $mensajes[] = 'Moneda y tasa de cambio actualizadas';
                }

                // Actualizar contraseña si fue enviada
                if ($newPass) {
                    $nuevoHash = password_hash($newPass, PASSWORD_BCRYPT);
                    $stmtPass = $pdo->prepare("SELECT fn_admin_set_password(?, ?)");
                    $stmtPass->execute([$adminId, $nuevoHash]);
                    $resPass = json_decode($stmtPass->fetchColumn(), true);
                    if (!$resPass['ok']) { echo json_encode($resPass); exit; }
                    $mensajes[] = 'Contraseña actualizada';
                }

                $msg = count($mensajes) > 0
                    ? implode(', ', $mensajes) . ' correctamente'
                    : 'No se realizaron cambios';

                echo json_encode(['ok' => true, 'msg' => $msg]);

            } else {
                // Fallback: update_store legacy
                $stmt = $pdo->prepare("SELECT fn_admin_update_settings(?::json)");
                $stmt->execute([json_encode($data)]);
                echo json_encode(json_decode($stmt->fetchColumn(), true));
            }
            break;

        default:
            http_response_code(405);
            echo json_encode(['ok' => false, 'msg' => 'Método no soportado para ajustes globales']);
            break;
    }
} catch (PDOException $e) {
    http_response_code(500);
    error_log('[admin_settings.php] ' . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.']);
}
