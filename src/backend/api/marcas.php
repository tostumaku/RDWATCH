<?php
/**
 * ============================================================
 * API: GESTIÓN DE MARCAS (marcas.php)
 * ============================================================
 * ENDPOINTS:
 *   GET    /api/marcas.php → Listar todas las marcas
 *   POST   /api/marcas.php → Crear nueva marca
 *   PUT    /api/marcas.php → Actualizar marca existente
 *   DELETE /api/marcas.php → Eliminar marca (con protección)
 *
 * PROPÓSITO:
 * CRUD de marcas de relojes (ej: Rolex, Casio, Seiko...).
 * Cada producto tiene exactamente UNA marca. Por eso el DELETE
 * verifica si hay productos vinculados antes de borrar.
 *
 * PERMISOS:
 * - GET: público
 * - POST/PUT/DELETE: solo admin
 *
 * FUNCIONES POSTGRESQL QUE USA:
 * - fn_cat_get_marcas()             → JSON array de marcas
 * - fn_cat_create_marca(id,nom,est) → JSON {ok, msg}
 * - fn_cat_update_marca(id,nom,est) → JSON {ok, msg}
 * - fn_cat_delete_marca(id)         → JSON con protección de productos
 * ============================================================
 */

header('Content-Type: application/json');
require_once '../config.php';
require_once '../utils/security_utils.php';
require_once '../utils/Validation.php';

// Verificar conexión
if (!isset($pdo)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error de Infraestructura: Motor de datos no disponible']);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'];

try {
    switch ($method) {
        // ══════════════════════════════════════
        // GET: LISTAR TODAS LAS MARCAS
        // ══════════════════════════════════════
        // fn_cat_get_marcas() retorna JSON array con id, nombre, estado
        // Si no hay marcas, retorna [] (array vacío)
        case 'GET':
            $stmt = $pdo->prepare("SELECT fn_cat_get_marcas()");
            $stmt->execute();
            $marcas = json_decode($stmt->fetchColumn(), true);
            echo json_encode(['ok' => true, 'marcas' => $marcas]);
            break;

        // ══════════════════════════════════════
        // POST: CREAR NUEVA MARCA
        // ══════════════════════════════════════
        // fn_cat_create_marca verifica internamente:
        // - Que no exista otra marca con el mismo nombre
        // - Que no exista otra marca con el mismo ID
        case 'POST':
            requireRole('admin');
            validateCsrfToken(null, true);

            $data = getCachedJsonInput();
            Validation::validateOrReject($data, [
                'id_marca' => 'id', // Numérico
                'nom_marca' => 'name' // Texto no vacío
            ]);

            // estado_marca: controla si la marca aparece en dropdowns
            // TRUE=activa (aparece), FALSE=desactivada (oculta)
            $estado = isset($data['estado_marca']) ? ($data['estado_marca'] ? true : false) : true;

            // El booleano se pasa como 'true'/'false' string para PostgreSQL
            $stmt = $pdo->prepare("SELECT fn_cat_create_marca(?, ?, ?)");
            $stmt->execute([$data['id_marca'], $data['nom_marca'], $estado]);
            echo json_encode(json_decode($stmt->fetchColumn(), true));
            break;

        // ══════════════════════════════════════
        // PUT: ACTUALIZAR MARCA
        // ══════════════════════════════════════
        case 'PUT':
            requireRole('admin');
            validateCsrfToken(null, true);

            $data = getCachedJsonInput();
            if (!isset($data['id_marca'], $data['nom_marca'])) {
                echo json_encode(['ok' => false, 'msg' => 'Datos insuficientes para la actualización']);
                exit;
            }

            $estado = isset($data['estado_marca']) ? ($data['estado_marca'] ? true : false) : true;

            $stmt = $pdo->prepare("SELECT fn_cat_update_marca(?, ?, ?)");
            $stmt->execute([$data['id_marca'], $data['nom_marca'], $estado]);
            echo json_encode(json_decode($stmt->fetchColumn(), true));
            break;

        // ══════════════════════════════════════
        // DELETE: SOFT DELETE DE MARCA (CON PROTECCIÓN)
        // ══════════════════════════════════════
        // fn_cat_delete_marca cuenta productos activos vinculados:
        // - Si hay N → "Existen N productos activos..." (bloquea)
        // - Si hay 0 → marca estado_marca=FALSE, registra usr_delete y fec_delete
        case 'DELETE':
            requireRole('admin');
            validateCsrfToken(null, true);

            $data = getCachedJsonInput();
            $idMarca = $data['id_marca'] ?? null;

            if (!$idMarca) {
                echo json_encode(['ok' => false, 'msg' => 'Se requiere el ID de la marca']);
                exit;
            }

            $stmt = $pdo->prepare("SELECT fn_cat_delete_marca(?::INTEGER)");
            $stmt->execute([$idMarca]);
            echo json_encode(json_decode($stmt->fetchColumn(), true));
            break;

        default:
            http_response_code(405);
            echo json_encode(['ok' => false, 'msg' => 'Método no permitido']);
            break;
    }
}
catch (Throwable $e) {
    http_response_code(500);
    error_log('[marcas.php] ' . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.']);
}
