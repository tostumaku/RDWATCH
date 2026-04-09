<?php
/**
 * ============================================================
 * API: PROCESO DE PAGO / CHECKOUT (checkout.php)
 * ============================================================
 * ENDPOINT: POST /api/checkout.php
 *
 * PROPÓSITO:
 * Es el NÚCLEO TRANSACCIONAL del sistema. Convierte un carrito
 * de compras activo en una orden formal, gestionando:
 * - Orden de compra (cabecera + detalles)
 * - Factura legal (cabecera + detalles)
 * - Descuento de inventario (stock)
 * - Dirección de envío (nueva o existente)
 * - Registro de envío logístico
 * - Registro de pago + comprobante bancario
 *
 * TODO LO ANTERIOR OCURRE EN UNA SOLA FUNCIÓN ATÓMICA:
 * fn_checkout_process — si falla CUALQUIER paso, no se guarda NADA.
 *
 * NOTA SOBRE EL COMPROBANTE (BYTEA):
 * El comprobante de pago es un archivo binario (imagen JPG/PNG/SVG).
 * Se almacena como BYTEA en PostgreSQL. Dado que PostgreSQL no puede
 * recibir BYTEA como parámetro de función fácilmente, el binario se
 * inserta DESPUÉS de la función atómica mediante un UPDATE directo.
 * Sin embargo, este UPDATE es la ÚNICA query no-opaca (por necesidad
 * técnica de LOB/BYTEA), y se hace sobre el ID del pago retornado
 * por fn_checkout_process.
 *
 * FUNCIONES POSTGRESQL QUE USA:
 * - fn_checkout_process(user, dirección, ciudad, método) → JSON
 *   Internamente toca 8 tablas en 10 pasos atómicos
 *
 * FLUJO COMPLETO:
 * 1. Validar sesión + CSRF
 * 2. Validar inputs (dirección, ciudad, comprobante)
 * 3. Validar archivo comprobante (MIME, extensión, tamaño)
 * 4. Llamar fn_checkout_process → orden atómica
 * 5. Actualizar registro de pago con comprobante binario
 * ============================================================
 */

header('Content-Type: application/json');
require_once '../config.php';
require_once '../utils/Validation.php';

// Verificación de la BD
if (!isset($pdo)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error de conexión con el motor de base de datos']);
    exit;
}

// Sesión PHP
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// ──────────────────────────────────────────────
// PASO 1: VERIFICACIÓN DE SESIÓN
// ──────────────────────────────────────────────
if (!isset($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['ok' => false, 'msg' => 'Acceso denegado: Debe estar autenticado']);
    exit;
}

// CSRF OBLIGATORIO para operación financiera
require_once '../utils/security_utils.php';
validateCsrfToken($_POST['csrf_token'] ?? null, true);

$userId = $_SESSION['user_id'];
$input = $_POST;
$file = $_FILES['payment_proof'] ?? null;

// ──────────────────────────────────────────────
// PASO 2: VALIDACIÓN DE INPUTS
// ──────────────────────────────────────────────
Validation::validateOrReject($input, [
    'direccion' => 'address',
    'ciudad' => 'name'
]);

if (!$file) {
    echo json_encode(['ok' => false, 'msg' => 'Falta el comprobante de pago']);
    exit;
}

$direccion = Validation::sanitizeString($input['direccion']);
$ciudad = Validation::sanitizeString($input['ciudad']);

// ──────────────────────────────────────────────
// PASO 3: VALIDACIÓN EXHAUSTIVA DEL COMPROBANTE
// ──────────────────────────────────────────────
// 3a: Error de upload
if ($file['error'] !== UPLOAD_ERR_OK) {
    echo json_encode(['ok' => false, 'msg' => 'Error al cargar el comprobante de pago']);
    exit;
}

// 3b: Validar tipo MIME real (no la extensión que puede ser falsificada)
$allowedMimeTypes = ['image/jpeg', 'image/png', 'image/svg+xml'];
$finfo = finfo_open(FILEINFO_MIME_TYPE);
$mimeType = finfo_file($finfo, $file['tmp_name']);
finfo_close($finfo);

if (!in_array($mimeType, $allowedMimeTypes)) {
    echo json_encode(['ok' => false, 'msg' => 'El comprobante debe ser una imagen (JPG, PNG o SVG)']);
    exit;
}

// 3c: Validar extensión
$allowedExtensions = ['jpg', 'jpeg', 'png', 'svg'];
$fileExtension = strtolower(pathinfo($file['name'], PATHINFO_EXTENSION));
if (!in_array($fileExtension, $allowedExtensions)) {
    echo json_encode(['ok' => false, 'msg' => 'Extensión de archivo no permitida. Use JPG, PNG o SVG']);
    exit;
}

// 3d: Validar tamaño (máximo 5MB)
$maxSize = 5 * 1024 * 1024;
if ($file['size'] > $maxSize) {
    echo json_encode(['ok' => false, 'msg' => 'El comprobante no debe superar los 5MB']);
    exit;
}

// 3e: Generar nombre único y mover archivo al disco
$timestamp    = date('Ymd_His');                                         // Ej: 20260303_191500
$fileName     = "{$userId}_{$timestamp}.{$fileExtension}";               // Ej: 7_20260303_191500.jpg
$uploadDir    = dirname(__DIR__, 2) . '/comprobantes/';                   // Ruta absoluta en servidor
$destPath     = $uploadDir . $fileName;
$rutaRelativa = 'comprobantes/' . $fileName;                             // Lo que se guarda en BD

if (!is_dir($uploadDir)) {
    mkdir($uploadDir, 0755, true); // Crear directorio si no existe
}

if (!move_uploaded_file($file['tmp_name'], $destPath)) {
    echo json_encode(['ok' => false, 'msg' => 'Error al guardar el comprobante en el servidor']);
    exit;
}

try {
    // ──────────────────────────────────────────────
    // PASO 4: FUNCIÓN ATÓMICA DE CHECKOUT
    // ──────────────────────────────────────────────
    // fn_checkout_process ejecuta TODO dentro de PostgreSQL:
    // - Busca carrito activo
    // - Valida stock de cada producto
    // - Crea orden + factura + detalles
    // - Descuenta stock
    // - Registra dirección + envío + pago
    // - Limpia y cierra el carrito
    // Si CUALQUIER paso falla → todo se revierte automáticamente
    $metodoDesc = Validation::sanitizeString($input['metodo'] ?? 'Consignación Bancaria');

    $stmt = $pdo->prepare("SELECT fn_checkout_process(?::INTEGER, ?, ?, ?)");
    $stmt->execute([$userId, $direccion, $ciudad, $metodoDesc]);
    $result = json_decode($stmt->fetchColumn(), true);

    if (!$result['ok']) {
        // Validación de stock falló o carrito vacío → sin daños
        http_response_code(400);
        echo json_encode($result);
        exit;
    }

    // ──────────────────────────────────────────────
    // PASO 5: GUARDAR RUTA DEL COMPROBANTE EN BD
    // ──────────────────────────────────────────────
    // El archivo ya está en disco. Solo guardamos la ruta relativa.
    $stmtPago = $pdo->prepare("UPDATE tab_Pagos SET comprobante_ruta = ? WHERE id_pago = ?");
    $stmtPago->execute([$rutaRelativa, $result['payment_id']]);

    // Respuesta exitosa
    echo json_encode([
        'ok' => true,
        'msg' => $result['msg'],
        'order_id' => $result['order_id']
    ]);

}
catch (Exception $e) {
    http_response_code(400);
    error_log('[checkout.php] ' . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.']);
}
