<?php
/**
 * ============================================================
 * API: VISUALIZADOR DE COMPROBANTES EN DISCO (get_comprobante.php)
 * ============================================================
 * ENDPOINT: GET /api/get_comprobante.php?id_orden=X
 *
 * PROPÓSITO:
 * Sirve imágenes de comprobantes de pago guardadas en disco
 * (carpeta src/comprobantes/). Los admins lo usan para validar
 * transferencias bancarias.
 *
 * ACCESO: SOLO ADMIN (requireRole('admin'))
 *
 * FUNCIÓN POSTGRESQL QUE USA:
 * - fn_receipt_get_path(order_id) → TEXT (ruta relativa del archivo)
 *
 * FLUJO:
 * 1. Validar sesión admin
 * 2. Llamar fn_receipt_get_path → obtener ruta del archivo
 * 3. Construir ruta absoluta en servidor
 * 4. Detectar MIME type por extensión
 * 5. Servir el archivo con readfile()
 * ============================================================
 */

require_once '../config.php';
require_once '../utils/security_utils.php';

if (!isset($pdo)) {
    http_response_code(500);
    die('Error crítico: El motor de base de datos no está disponible');
}

// 🛡️ BARRERA ADMINISTRATIVA
requireRole('admin');

$id_orden = (int)($_GET['id_orden'] ?? 0);
if (!$id_orden) {
    http_response_code(400);
    die('Solicitud Inválida: ID de orden ausente o inválido');
}

try {
    // ══════════════════════════════════════
    // 🔍 OBTENER RUTA DEL COMPROBANTE
    // ══════════════════════════════════════
    $stmt = $pdo->prepare("SELECT fn_receipt_get_path(?)");
    $stmt->execute([$id_orden]);
    $rutaRelativa = $stmt->fetchColumn();

    if (!$rutaRelativa) {
        http_response_code(404);
        die('Comprobante no encontrado: La orden no tiene un comprobante de pago registrado');
    }

    // Construir ruta absoluta (desde api/ → subir 3 niveles → src/comprobantes/)
    $rutaAbsoluta = dirname(__DIR__, 2) . '/' . $rutaRelativa;

    if (!file_exists($rutaAbsoluta)) {
        http_response_code(404);
        die('Archivo no encontrado en el servidor: ' . basename($rutaRelativa));
    }

    // Detectar MIME type por extensión
    $ext = strtolower(pathinfo($rutaAbsoluta, PATHINFO_EXTENSION));
    $mimeMap = [
        'jpg'  => 'image/jpeg',
        'jpeg' => 'image/jpeg',
        'png'  => 'image/png',
        'svg'  => 'image/svg+xml',
        'gif'  => 'image/gif',
        'webp' => 'image/webp',
    ];
    $mimeType = $mimeMap[$ext] ?? 'application/octet-stream';

    // Despacho del archivo desde disco
    header("Content-Type: $mimeType");
    header('Content-Disposition: inline; filename="' . basename($rutaAbsoluta) . '"');
    header('Content-Length: ' . filesize($rutaAbsoluta));
    header('Cache-Control: private, max-age=3600');

    if (ob_get_length()) ob_clean();
    flush();
    readfile($rutaAbsoluta);
    exit;

} catch (PDOException $e) {
    http_response_code(500);
    error_log('[get_comprobante.php] ' . $e->getMessage());
    http_response_code(500); die(json_encode(['ok' => false, 'msg' => 'Error interno del servidor.']));
}
