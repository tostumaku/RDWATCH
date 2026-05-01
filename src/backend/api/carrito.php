<?php
/**
 * ============================================================
 * API: GESTIÓN DE CARRITO DE COMPRAS (carrito.php)
 * ============================================================
 * ENDPOINTS:
 *   GET    /api/carrito.php → Listar contenido del carrito
 *   POST   /api/carrito.php → Agregar producto al carrito
 *   PUT    /api/carrito.php → Actualizar cantidad de un ítem
 *   DELETE /api/carrito.php → Quitar producto o vaciar todo
 *
 * PROPÓSITO:
 * Administra la persistencia de productos seleccionados por
 * el cliente. El carrito se guarda en BD (no en localStorage)
 * para preservar ítems entre sesiones y dispositivos.
 *
 * REQUISITO: Sesión de usuario activa ($_SESSION['user_id']).
 *
 * FUNCIONES POSTGRESQL QUE USA:
 * - fn_cart_get_or_create(user_id) → JSON {id_carrito, created}
 * - fn_cart_get_items(cart_id)     → JSON array con ítems
 * - fn_cart_add_item(cart, prod, qty) → JSON {ok, msg}
 * - fn_cart_update_qty(cart, prod, qty) → JSON {ok, msg}
 * - fn_cart_remove_item(cart, prod) → JSON {ok, msg}
 * - fn_cart_clear(cart_id)          → JSON {ok, msg}
 *
 * FLUJO:
 * 1. Verificar sesión activa
 * 2. Obtener/crear carrito: fn_cart_get_or_create
 * 3. Ejecutar operación según método HTTP
 * ============================================================
 */

header('Content-Type: application/json');
require_once '../config.php';
require_once '../utils/Validation.php';
require_once '../utils/security_utils.php';

// Verificación de integridad de la conexión
if (!isset($pdo)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error técnico: Conexión a BD no disponible']);
    exit;
}

// Asegurar sesión PHP activa
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// ──────────────────────────────────────────────
// SEGURIDAD: CONTROL DE ACCESO
// ──────────────────────────────────────────────
// El carrito es privado del usuario autenticado
if (!isset($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['ok' => false, 'msg' => 'Sesión no válida o expirada. Inicie sesión de nuevo.']);
    exit;
}

$userId = $_SESSION['user_id'];
$method = $_SERVER['REQUEST_METHOD'];

try {
    // ──────────────────────────────────────────────
    // INICIALIZACIÓN: Obtener/crear carrito activo
    // ──────────────────────────────────────────────
    // fn_cart_get_or_create busca un carrito con estado 'activo'
    // Si no existe, crea uno automáticamente
    // Retorna: {id_carrito: 123, created: true/false}
    $cartStmt = $pdo->prepare("SELECT fn_cart_get_or_create(?::INTEGER)");
    $cartStmt->execute([$userId]);
    $cartData = json_decode($cartStmt->fetchColumn(), true);
    $carritoId = $cartData['id_carrito'];

    switch ($method) {
        // ══════════════════════════════════════
        // GET: LISTAR CONTENIDO DEL CARRITO
        // ══════════════════════════════════════
        // fn_cart_get_items hace JOIN interno con tab_Productos
        // para obtener nombres, precios ACTUALES e imágenes
        case 'GET':
            $stmt = $pdo->prepare("SELECT fn_cart_get_items(?::INTEGER)");
            $stmt->execute([$carritoId]);
            $json = $stmt->fetchColumn() ?: '[]';
            echo '{"ok":true,"items":' . $json . '}';
            break;

        // ══════════════════════════════════════
        // POST: AGREGAR PRODUCTO
        // ══════════════════════════════════════
        // fn_cart_add_item tiene lógica inteligente:
        // - Si el producto YA está → incrementa cantidad
        // - Si es nuevo → lo inserta
        case 'POST':
            validateCsrfToken(null, true);
            $data = getJsonInput();

            $id_prod = Validation::validateNumeric($data['id_producto'] ?? '') ? (int)$data['id_producto'] : null;
            $qty = Validation::validateNumeric($data['cantidad'] ?? '') ? (int)$data['cantidad'] : null;

            if (!$id_prod || !$qty) {
                http_response_code(400);
                echo json_encode(['ok' => false, 'msg' => 'Parámetros id_producto y cantidad son obligatorios y deben ser válidos']);
                exit;
            }

            // Consulta 100% opaca
            $stmt = $pdo->prepare("SELECT fn_cart_add_item(?::INTEGER, ?::INTEGER, ?::INTEGER)");
            $stmt->execute([$carritoId, $id_prod, $qty]);
            $jsonResponse = $stmt->fetchColumn();
            echo $jsonResponse ? $jsonResponse : json_encode(['ok' => false, 'msg' => 'Respuesta vacía de BD']);
            break;

        // ══════════════════════════════════════
        // PUT: ACTUALIZAR CANTIDAD
        // ══════════════════════════════════════
        // Reemplaza la cantidad actual (no incrementa)
        case 'PUT':
            validateCsrfToken(null, true);
            $data = getJsonInput();
            $id_prod = Validation::validateNumeric($data['id_producto'] ?? '') ? (int)$data['id_producto'] : null;
            $qty = Validation::validateNumeric($data['cantidad'] ?? '') ? (int)$data['cantidad'] : null;

            if (!$id_prod || !$qty) {
                http_response_code(400);
                echo json_encode(['ok' => false, 'msg' => 'Datos insuficientes o inválidos para actualizar']);
                exit;
            }

            $stmt = $pdo->prepare("SELECT fn_cart_update_qty(?::INTEGER, ?::INTEGER, ?::INTEGER)");
            $stmt->execute([$carritoId, $id_prod, $qty]);
            $jsonResponse = $stmt->fetchColumn();
            echo $jsonResponse ? $jsonResponse : json_encode(['ok' => false, 'msg' => 'Respuesta vacía de BD']);
            break;

        // ══════════════════════════════════════
        // DELETE: QUITAR PRODUCTO O VACIAR
        // ══════════════════════════════════════
        // Con id_producto → quita solo ese producto
        // Sin id_producto → vacía todo el carrito
        case 'DELETE':
            validateCsrfToken(null, true);
            $data = getJsonInput();
            $id_prod = $data['id_producto'] ?? null;

            if ($id_prod) {
                // Eliminación quirúrgica de UN producto
                $stmt = $pdo->prepare("SELECT fn_cart_remove_item(?::INTEGER, ?::INTEGER)");
                $stmt->execute([$carritoId, $id_prod]);
            }
            else {
                // Vaciado total
                $stmt = $pdo->prepare("SELECT fn_cart_clear(?::INTEGER)");
                $stmt->execute([$carritoId]);
            }
            $jsonResponse = $stmt->fetchColumn();
            echo $jsonResponse ? $jsonResponse : json_encode(['ok' => false, 'msg' => 'Respuesta vacía de BD']);
            break;

        default:
            http_response_code(405);
            echo json_encode(['ok' => false, 'msg' => 'Esta API no soporta el método solicitado']);
            break;
    }

}
catch (PDOException $e) {
    http_response_code(500);
    error_log('[carrito.php] ' . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.']);
}
