<?php
/**
 * ============================================================
 * API: GESTIÓN DE PEDIDOS / ÓRDENES (pedidos.php)
 * ============================================================
 * ENDPOINTS:
 *   GET /api/pedidos.php → Listar pedidos (con filtros opcionales)
 *   PUT /api/pedidos.php → Actualizar estado logístico
 *
 * PROPÓSITO:
 * Panel administrativo de pedidos. Permite ver el historial de
 * compras de TODOS los clientes y gestionar su estado logístico
 * (pendiente → confirmado → enviado → entregado).
 *
 * ACCESO: SOLO ADMIN (requireRole('admin'))
 *
 * FUNCIONES POSTGRESQL QUE USA:
 * - fn_orders_list(estado, búsqueda, from, to) → JSON array
 *   Acepta 4 filtros opcionales (NULL = sin filtro)
 *   Internamente hace JOIN con usuarios y pagos
 * - fn_orders_update_status(order_id, estado) → JSON {ok, msg}
 *   Incluye lista blanca de estados válidos
 *
 * FILTROS DEL GET:
 * - ?estado=pendiente → filtrar por estado
 * - ?busqueda=juan → buscar en nombre o email del cliente
 * - ?date_from=2026-01-01 → desde fecha
 * - ?date_to=2026-12-31 → hasta fecha
 * ============================================================
 */

header('Content-Type: application/json');
require_once '../config.php';
require_once '../utils/security_utils.php';
require_once '../utils/Validation.php';

// ──────────────────────────────────────────────
// BARRERA ADMINISTRATIVA: Solo admins
// ──────────────────────────────────────────────
requireRole('admin');

if (!isset($pdo)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error de configuración de BD']);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'];

try {
    if ($method === 'GET') {
        // ══════════════════════════════════════
        // LISTAR PEDIDOS (con filtros opcionales)
        // ══════════════════════════════════════
        // Los filtros se pasan como NULL si no están presentes
        // fn_orders_list los aplica condicionalmente
        $estado = !empty($_GET['estado']) ? $_GET['estado'] : null;
        $busqueda = !empty($_GET['busqueda']) ? $_GET['busqueda'] : null;
        $dateFrom = !empty($_GET['date_from']) ? $_GET['date_from'] : null;
        $dateTo = !empty($_GET['date_to']) ? $_GET['date_to'] : null;

        // Consulta opaca: los 4 parámetros pueden ser NULL
        $stmt = $pdo->prepare("SELECT fn_orders_list(?, ?, ?, ?)");
        $stmt->execute([$estado, $busqueda, $dateFrom, $dateTo]);
        $json = $stmt->fetchColumn() ?: '[]';

        echo '{"ok":true,"pedidos":' . $json . '}';

    }
    elseif ($method === 'PUT') {
        // ══════════════════════════════════════
        // ACTUALIZAR ESTADO DE PEDIDO
        // ══════════════════════════════════════
        validateCsrfToken(null, true);
        $input = getJsonInput();

        Validation::validateOrReject($input, [
            'id_orden' => 'id',
            'estado' => 'name'
        ]);

        $id_orden = $input['id_orden'];
        $nuevo_estado = $input['estado'];

        if (!$id_orden || !$nuevo_estado) {
            http_response_code(400);
            echo json_encode(['ok' => false, 'msg' => 'Se requiere el ID de la orden y el nuevo estado']);
            exit;
        }

        // fn_orders_update_status valida internamente la lista blanca
        // de estados: pendiente, confirmado, enviado, cancelado, entregado
        $stmt = $pdo->prepare("SELECT fn_orders_update_status(?::INTEGER, ?)");
        $stmt->execute([$id_orden, $nuevo_estado]);
        $jsonResponse = $stmt->fetchColumn();
        echo $jsonResponse ? $jsonResponse : json_encode(['ok' => false, 'msg' => 'Respuesta vacía de BD']);

    }
    else {
        http_response_code(405);
        echo json_encode(['ok' => false, 'msg' => 'Método no soportado por esta API']);
    }
}
catch (PDOException $e) {
    http_response_code(500);
    error_log('[pedidos.php] ' . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.']);
}
