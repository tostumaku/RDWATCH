<?php
/**
 * ============================================================
 * API: FACTURACIÓN DETALLADA (get_factura.php)
 * ============================================================
 * ENDPOINT: GET /api/get_factura.php?id_orden=X
 *
 * PROPÓSITO:
 * Recupera toda la información legal y comercial de una orden
 * para su visualización en formato de factura electrónica.
 *
 * SEGURIDAD:
 * - Sesión obligatoria
 * - Protección IDOR: fn_invoice_get_header verifica internamente
 *   que la factura pertenezca al user_id de la sesión
 *
 * FUNCIONES POSTGRESQL QUE USA:
 * - fn_invoice_get_header(order_id, user_id) → JSON (cabecera)
 * - fn_invoice_get_items(order_id)           → JSON array (productos)
 *
 * DATOS CONSOLIDADOS:
 * - Cabecera: Factura + Orden + Perfil del Cliente (JOIN triple)
 * - Detalle: Lista de ítems con precios y subtotales
 * ============================================================
 */

header('Content-Type: application/json');
require_once '../config.php';

if (!isset($pdo)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error técnico: El motor de facturación no responde']);
    exit;
}

if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// Barrera de autenticación
if (!isset($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['ok' => false, 'msg' => 'Acceso denegado: Inicie sesión para consultar sus comprobantes']);
    exit;
}

$idOrden = $_GET['id_orden'] ?? null;
if (!$idOrden) {
    echo json_encode(['ok' => false, 'msg' => 'Solicitud incompleta: ID de orden no especificado']);
    exit;
}

try {
    // ══════════════════════════════════════
    // 📄 CABECERA DE FACTURACIÓN
    // ══════════════════════════════════════
    // fn_invoice_get_header incluye protección IDOR:
    // Solo retorna datos si id_usuario de la factura == session user_id
    $stmtFact = $pdo->prepare("SELECT fn_invoice_get_header(?, ?)");
    $stmtFact->execute([$idOrden, $_SESSION['user_id']]);
    $factura = json_decode($stmtFact->fetchColumn(), true);

    if (!$factura) {
        echo json_encode(['ok' => false, 'msg' => 'Información restringida o factura inexistente']);
        exit;
    }

    // ══════════════════════════════════════
    // 🛒 DETALLE DE PRODUCTOS
    // ══════════════════════════════════════
    $stmtProd = $pdo->prepare("SELECT fn_invoice_get_items(?)");
    $stmtProd->execute([$idOrden]);
    $productos = json_decode($stmtProd->fetchColumn(), true);

    echo json_encode([
        'ok' => true,
        'factura' => $factura,
        'productos' => $productos,
        'msg' => 'Datos de facturación recuperados correctamente'
    ]);

}
catch (PDOException $e) {
    http_response_code(500);
    error_log('[get_factura.php] ' . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.']);
}
