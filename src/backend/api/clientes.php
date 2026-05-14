<?php
/**
 * ============================================================
 * API: ADMINISTRACIÓN DE CLIENTES (clientes.php)
 * ============================================================
 * ENDPOINTS:
 *   GET /api/clientes.php → Listar todos los clientes
 *   PUT /api/clientes.php → Activar/desactivar un cliente
 *
 * PROPÓSITO:
 * Panel administrativo para gestionar la base de clientes.
 * Solo el admin puede ver la lista y cambiar el estado
 * activo/inactivo de una cuenta.
 *
 * ACCESO: SOLO ADMIN (requireRole('admin'))
 *
 * FUNCIONES POSTGRESQL QUE USA:
 * - fn_admin_list_clients()           → JSON array de clientes
 * - fn_admin_toggle_client(id, state) → JSON {ok, msg}
 *   (incluye verificación interna de que el target sea 'cliente')
 *
 * SEGURIDAD INTERNA (dentro de fn_admin_toggle_client):
 * - Barrera de rol: solo permite modificar cuentas con rol 'cliente'
 * - Impide que un admin desactive a otro admin
 * - Si el target no existe, retorna error descriptivo
 * ============================================================
 */

header('Content-Type: application/json');
require_once '../config.php';
require_once '../utils/security_utils.php';

// 🛡️ BARRERA ADMINISTRATIVA
requireRole('admin');

if (!isset($pdo)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error de conexión: El motor de base de datos no está disponible']);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'];

try {
    if ($method === 'GET') {
        // ══════════════════════════════════════
        // 🔍 LISTAR CLIENTES
        // ══════════════════════════════════════
        // fn_admin_list_clients filtra internamente por rol='cliente'
        // y excluye contraseñas y datos sensibles
        $stmt = $pdo->prepare("SELECT fn_admin_list_clients()");
        $stmt->execute();
        $clientes = json_decode($stmt->fetchColumn(), true);

        echo json_encode([
            'ok' => true,
            'count' => count($clientes),
            'clientes' => $clientes
        ]);

    }
    elseif ($method === 'PUT') {
        // ══════════════════════════════════════
        // 🔄 ACTIVAR/DESACTIVAR CLIENTE
        // ══════════════════════════════════════
        validateCsrfToken(null, true);
        $data = getJsonInput();

        if (!isset($data['id_usuario'], $data['activo'])) {
            http_response_code(400);
            echo json_encode(['ok' => false, 'msg' => 'Datos incompletos para actualizar estado']);
            exit;
        }

        $id = (int)$data['id_usuario'];
        $nuevoEstado = $data['activo'] ? true : false;

        // fn_admin_toggle_client verifica internamente:
        // 1. Que el usuario exista
        // 2. Que sea 'cliente' (no admin)
        // 3. Solo entonces aplica el cambio
        $stmt = $pdo->prepare("SELECT fn_admin_toggle_client(?, ?)");
        $stmt->execute([$id, $nuevoEstado ? 'true' : 'false']);
        $jsonResponse = $stmt->fetchColumn();
        echo $jsonResponse ? $jsonResponse : json_encode(['ok' => false, 'msg' => 'Respuesta vacía de BD']);

    }
    else {
        http_response_code(405);
        echo json_encode(['ok' => false, 'msg' => 'Método HTTP denegado para la gestión de clientes']);
    }
}
catch (PDOException $e) {
    http_response_code(500);
    error_log('[clientes.php] ' . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.']);
}
