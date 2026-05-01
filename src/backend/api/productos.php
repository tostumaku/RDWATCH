<?php
/**
 * ============================================================
 * API: GESTIÓN DE PRODUCTOS / CATÁLOGO DE RELOJES (productos.php)
 * ============================================================
 * ENDPOINTS:
 *   GET    /api/productos.php → Listar todos los productos
 *   POST   /api/productos.php → Crear un nuevo producto
 *   PUT    /api/productos.php → Actualizar un producto existente
 *   DELETE /api/productos.php → Eliminar un producto
 *
 * PROPÓSITO:
 * CRUD completo para el catálogo de relojes. Los productos son
 * el corazón del e-commerce. Cada producto tiene una marca,
 * una categoría y una subcategoría dentro de esa categoría.
 *
 * PERMISOS:
 * - GET: público (cualquiera puede ver el catálogo)
 * - POST/PUT/DELETE: solo admin (requireRole('admin'))
 *
 * FUNCIONES POSTGRESQL QUE USA:
 * - fn_cat_get_productos()          → JSON array de todos los productos con JOINs
 * - fn_cat_create_producto(...)     → JSON {ok, msg} con 3 validaciones
 * - fn_cat_update_producto(...)     → JSON {ok, msg} con re-validación
 * - fn_cat_delete_producto(id)      → JSON {ok, msg} con 2 protecciones
 *
 * PRINCIPIO DE OCULTACIÓN TOTAL:
 * PHP solo ejecuta "SELECT fn_cat_xxx(...)" y recibe JSON.
 * No se menciona NINGÚN nombre de tabla ni columna en las queries.
 * ============================================================
 */

header('Content-Type: application/json');
require_once '../config.php';
require_once '../utils/security_utils.php';
require_once '../utils/Validation.php';

// Verificar que la conexión a BD esté disponible
if (!isset($pdo)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error técnico: Conector de datos no inicializado']);
    exit;
}

// Detectar qué método HTTP se usó (GET, POST, PUT, DELETE)
$method = $_SERVER['REQUEST_METHOD'];

try {
    switch ($method) {
        // ══════════════════════════════════════
        // GET: LISTAR TODOS LOS PRODUCTOS
        // ══════════════════════════════════════
        // Público — cualquier visitante puede ver el catálogo
        // fn_cat_get_productos() internamente hace 3 LEFT JOINs con
        // marcas, categorías y subcategorías, pero PHP no lo sabe
        case 'GET':
            $stmt = $pdo->prepare("SELECT fn_cat_get_productos()");
            $stmt->execute();
            // fetchColumn() retorna el string JSON directamente
            $json = $stmt->fetchColumn() ?: '[]';
            echo '{"ok":true,"productos":' . $json . '}';
            break;

        // ══════════════════════════════════════
        // POST: CREAR NUEVO PRODUCTO
        // ══════════════════════════════════════
        // Solo admin — requireRole('admin') verifica $_SESSION['user_role']
        // validateCsrfToken protege contra ataques CSRF
        case 'POST':
            requireRole('admin'); // Solo administradores
            validateCsrfToken(null, true); // Protección CSRF

            $data = getJsonInput(); // Datos del formulario del admin

            // Validar que los campos requeridos tengan formato correcto
            Validation::validateOrReject($data, [
                'id_producto' => 'id', // Debe ser numérico
                'nom_producto' => 'name', // Texto no vacío
                'precio' => 'price', // Número positivo
                'stock' => 'stock', // Entero >= 0
                'id_marca' => 'id', // FK válida
                'id_categoria' => 'id', // FK válida
                'id_subcategoria' => 'id' // FK válida
            ]);

            // Campos opcionales con valores por defecto
            $img = $data['url_imagen'] ?? null; // URL imagen (puede no tener)
            $desc = Validation::sanitizeString($data['descripcion'] ?? ''); // Sanitizar desc
            $user_id = $_SESSION['user_id'] ?? 'admin_inventario'; // Quién lo creó

            // Consulta opaca: envía 10 parámetros, recibe JSON
            // ?::smallint hace cast explícito del stock a SMALLINT
            $stmt = $pdo->prepare("SELECT fn_cat_create_producto(?, ?, ?, ?, ?::smallint, ?, ?, ?, ?, ?)");
            $stmt->execute([
                $data['id_producto'], $data['nom_producto'], $desc,
                $data['precio'], $data['stock'], $img,
                $data['id_marca'], $data['id_categoria'], $data['id_subcategoria'],
                $user_id
            ]);
            // La respuesta YA viene formateada como {ok: bool, msg: string}
            $jsonResponse = $stmt->fetchColumn();
            echo $jsonResponse ? $jsonResponse : json_encode(['ok' => false, 'msg' => 'Respuesta vacía de BD']);
            break;

        // ══════════════════════════════════════
        // PUT: ACTUALIZAR PRODUCTO EXISTENTE
        // ══════════════════════════════════════
        case 'PUT':
            requireRole('admin');
            validateCsrfToken(null, true);

            $data = getJsonInput();
            // El ID es obligatorio para saber QUÉ producto actualizar
            if (!isset($data['id_producto'])) {
                http_response_code(400);
                echo json_encode(['ok' => false, 'msg' => 'Se requiere el ID del producto para realizar la actualización']);
                exit;
            }

            $img = $data['url_imagen'] ?? null;
            $desc = $data['descripcion'] ?? '';

            // fn_cat_update_producto re-valida la jerarquía categoría↔subcategoría
            $stmt = $pdo->prepare("SELECT fn_cat_update_producto(?, ?, ?, ?, ?::smallint, ?, ?, ?, ?, ?)");
            $stmt->execute([
                $data['id_producto'],
                sanitizeHtml($data['nom_producto']), // sanitizeHtml previene XSS
                sanitizeHtml($desc),
                $data['precio'], $data['stock'], $img,
                $data['id_marca'], $data['id_categoria'], $data['id_subcategoria'],
                isset($data['estado']) ? (bool)$data['estado'] : true
            ]);
            $jsonResponse = $stmt->fetchColumn();
            echo $jsonResponse ? $jsonResponse : json_encode(['ok' => false, 'msg' => 'Respuesta vacía de BD']);
            break;

        // ══════════════════════════════════════
        // DELETE: SOFT DELETE DE PRODUCTO
        // ══════════════════════════════════════
        // fn_cat_delete_producto verifica:
        //   1. ¿Tiene historial de ventas? → BLOQUEA
        //   2. ¿Está en algún carrito? → BLOQUEA
        //   Si pasa ambas → marca estado=FALSE, registra usr_delete y fec_delete
        case 'DELETE':
            requireRole('admin');
            validateCsrfToken(null, true);

            $data = getJsonInput();
            $pid = $data['id_producto'] ?? null;

            if (!$pid) {
                http_response_code(400);
                echo json_encode(['ok' => false, 'msg' => 'ID de producto no proporcionado']);
                exit;
            }

            $stmt = $pdo->prepare("SELECT fn_cat_delete_producto(?::INTEGER)");
            $stmt->execute([$pid]);
            $jsonResponse = $stmt->fetchColumn();
            echo $jsonResponse ? $jsonResponse : json_encode(['ok' => false, 'msg' => 'Respuesta vacía de BD']);
            break;

        default:
            http_response_code(405); // 405 = Method Not Allowed
            echo json_encode(['ok' => false, 'msg' => 'Método HTTP denegado para esta API']);
            break;
    }
}
catch (Throwable $e) {
    http_response_code(500);
    error_log('[productos.php] ' . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.']);
}
