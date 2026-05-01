<?php
/**
 * ============================================================
 * API: GESTIÓN DE CATEGORÍAS Y SUBCATEGORÍAS (categorias.php)
 * ============================================================
 * ENDPOINTS:
 *   # CATEGORÍAS (sin ?action=subcategoria):
 *   GET    /api/categorias.php → Listar categorías
 *   POST   /api/categorias.php → Crear categoría
 *   PUT    /api/categorias.php → Actualizar categoría
 *   DELETE /api/categorias.php → Eliminar categoría (doble protección)
 *
 *   # SUBCATEGORÍAS (con ?action=subcategoria):
 *   GET    /api/categorias.php?action=subcategoria → Listar subcategorías
 *   POST   /api/categorias.php?action=subcategoria → Crear subcategoría
 *   PUT    /api/categorias.php?action=subcategoria → Actualizar subcategoría
 *   DELETE /api/categorias.php?action=subcategoria → Eliminar subcategoría
 *
 * PROPÓSITO:
 * Este archivo maneja DOS entidades relacionadas:
 * - Categorías: primer nivel (ej: "Relojes de Lujo", "Deportivos")
 * - Subcategorías: segundo nivel dentro de una categoría (ej: "Automáticos")
 *
 * NOTA IMPORTANTE SOBRE SUBCATEGORÍAS:
 * Las subcategorías usan PK COMPUESTA (id_categoria, id_subcategoria).
 * Esto significa que la subcategoría ID 1 bajo categoría 1 es DIFERENTE
 * de la subcategoría ID 1 bajo categoría 2.
 *
 * FUNCIONES POSTGRESQL QUE USA:
 * Categorías:
 * - fn_cat_get_categorias()                              → JSON array
 * - fn_cat_create_categoria(id, nom, desc, estado)       → JSON {ok, msg}
 * - fn_cat_update_categoria(id, nom, desc, estado)       → JSON {ok, msg}
 * - fn_cat_delete_categoria(id)                          → JSON con doble protección
 * Subcategorías:
 * - fn_cat_get_subcategorias()                            → JSON array con JOIN
 * - fn_cat_create_subcategoria(id_cat, id_sub, nombre)    → JSON {ok, msg}
 * - fn_cat_update_subcategoria(id_cat, id_sub, nombre)    → JSON {ok, msg}
 * - fn_cat_delete_subcategoria(id_cat, id_sub)            → JSON con protección
 * ============================================================
 */

header('Content-Type: application/json');
require_once '../config.php';
require_once '../utils/security_utils.php';
require_once '../utils/Validation.php';

if (!isset($pdo)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error de Infraestructura: Motor de datos no disponible']);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'];

// ──────────────────────────────────────────────
// ENRUTAMIENTO POR QUERY PARAMETER
// ──────────────────────────────────────────────
// Si la URL tiene ?action=subcategoria → maneja subcategorías
// Si no tiene ?action → maneja categorías
// Esto permite que UN solo archivo PHP sirva para ambas entidades
$action = $_GET['action'] ?? '';

try {
    // ██████████████████████████████████████████
    // ██  BLOQUE A: SUBCATEGORÍAS              ██
    // ██████████████████████████████████████████
    if ($action === 'subcategoria') {
        switch ($method) {
            // LISTAR SUBCATEGORÍAS
            // fn_cat_get_subcategorias hace JOIN interno con tab_Categorias
            // para incluir el nombre de la categoría padre
            case 'GET':
                $stmt = $pdo->prepare("SELECT fn_cat_get_subcategorias()");
                $stmt->execute();
                $json = $stmt->fetchColumn() ?: '[]';
                echo '{"ok":true,"subcategorias":' . $json . '}';
                break;

            // CREAR SUBCATEGORÍA
            // Requiere: id_categoria (padre), id_subcategoria, nom_subcategoria
            case 'POST':
                requireRole('admin');
                validateCsrfToken(null, true);

                $data = getCachedJsonInput();
                Validation::validateOrReject($data, [
                    'id_categoria' => 'id', // ID de la categoría padre
                    'id_subcategoria' => 'id', // ID de la nueva subcategoría
                    'nom_subcategoria' => 'name' // Nombre de la subcategoría
                ]);

                $stmt = $pdo->prepare("SELECT fn_cat_create_subcategoria(?::SMALLINT, ?::SMALLINT, ?::TEXT)");
                $stmt->execute([$data['id_categoria'], $data['id_subcategoria'], $data['nom_subcategoria']]);
                $jsonResponse = $stmt->fetchColumn();
                echo $jsonResponse ? $jsonResponse : json_encode(['ok' => false, 'msg' => 'Respuesta vacía de BD']);
                break;

            // ACTUALIZAR SUBCATEGORÍA (nombre y/o estado)
            case 'PUT':
                requireRole('admin');
                validateCsrfToken(null, true);
                $data = getCachedJsonInput();

                $estado = isset($data['estado']) ? ($data['estado'] ? true : false) : true;

                $stmt = $pdo->prepare("SELECT fn_cat_update_subcategoria(?::SMALLINT, ?::SMALLINT, ?::TEXT, ?::BOOLEAN)");
                $stmt->execute([$data['id_categoria'], $data['id_subcategoria'], $data['nom_subcategoria'], $estado ? 'true' : 'false']);
                $jsonResponse = $stmt->fetchColumn();
                echo $jsonResponse ? $jsonResponse : json_encode(['ok' => false, 'msg' => 'Respuesta vacía de BD']);
                break;

            // DESACTIVAR SUBCATEGORÍA (soft delete con protección de productos activos)
            // Necesita AMBOS IDs porque es PK compuesta + usuario para auditoría
            case 'DELETE':
                requireRole('admin');
                validateCsrfToken(null, true);
                $data = getCachedJsonInput();

                $idCat = $data['id_categoria'] ?? null;
                $idSub = $data['id_subcategoria'] ?? null;

                if ($idCat === null || $idSub === null) {
                    http_response_code(400);
                    echo json_encode(['ok' => false, 'msg' => 'Faltan IDs de referencia para la desactivación']);
                    exit;
                }

                $stmt = $pdo->prepare("SELECT fn_cat_delete_subcategoria(?::SMALLINT, ?::SMALLINT, ?::VARCHAR)");
                $stmt->execute([$idCat, $idSub, 'admin_panel']);
                $jsonResponse = $stmt->fetchColumn();
                echo $jsonResponse ? $jsonResponse : json_encode(['ok' => false, 'msg' => 'Respuesta vacía de BD']);
                break;
        }
    }
    // ██████████████████████████████████████████
    // ██  BLOQUE B: CATEGORÍAS                 ██
    // ██████████████████████████████████████████
    else {
        switch ($method) {
            // LISTAR CATEGORÍAS
            case 'GET':
                $stmt = $pdo->prepare("SELECT fn_cat_get_categorias()");
                $stmt->execute();
                $json = $stmt->fetchColumn() ?: '[]';
                echo '{"ok":true,"categorias":' . $json . '}';
                break;

            // CREAR CATEGORÍA
            case 'POST':
                requireRole('admin');
                validateCsrfToken(null, true);
                $data = getCachedJsonInput();

                Validation::validateOrReject($data, [
                    'id_categoria' => 'id',
                    'nom_categoria' => 'name'
                ]);

                $estado = isset($data['estado']) ? ($data['estado'] ? true : false) : true;

                $stmt = $pdo->prepare("SELECT fn_cat_create_categoria(?::SMALLINT, ?::TEXT, ?::TEXT, ?::BOOLEAN)");
                $stmt->execute([
                    $data['id_categoria'],
                    $data['nom_categoria'],
                    $data['descripcion_categoria'] ?? '',
                    $estado ? 'true' : 'false'
                ]);
                $jsonResponse = $stmt->fetchColumn();
                echo $jsonResponse ? $jsonResponse : json_encode(['ok' => false, 'msg' => 'Respuesta vacía de BD']);
                break;

            // ACTUALIZAR CATEGORÍA
            case 'PUT':
                requireRole('admin');
                validateCsrfToken(null, true);
                $data = getCachedJsonInput();

                $estado = isset($data['estado']) ? ($data['estado'] ? true : false) : true;

                $stmt = $pdo->prepare("SELECT fn_cat_update_categoria(?::SMALLINT, ?::TEXT, ?::TEXT, ?::BOOLEAN)");
                $stmt->execute([
                    $data['id_categoria'],
                    $data['nom_categoria'],
                    $data['descripcion_categoria'] ?? '',
                    $estado ? 'true' : 'false'
                ]);
                $jsonResponse = $stmt->fetchColumn();
                echo $jsonResponse ? $jsonResponse : json_encode(['ok' => false, 'msg' => 'Respuesta vacía de BD']);
                break;

            // ELIMINAR CATEGORÍA (SOFT DELETE CON DOBLE PROTECCIÓN)
            // fn_cat_delete_categoria verifica:
            //   1. ¿Tiene subcategorías activas hijas? → BLOQUEA
            //   2. ¿Tiene productos activos vinculados? → BLOQUEA
            //   Si pasa ambas → marca estado=FALSE, registra usr_delete y fec_delete
            case 'DELETE':
                requireRole('admin');
                validateCsrfToken(null, true);
                $data = getCachedJsonInput();

                $idCat = $data['id_categoria'] ?? null;
                if ($idCat === null) {
                    http_response_code(400);
                    echo json_encode(['ok' => false, 'msg' => 'ID de categoría faltante']);
                    exit;
                }

                $stmt = $pdo->prepare("SELECT fn_cat_delete_categoria(?::SMALLINT)");
                $stmt->execute([$idCat]);
                $jsonResponse = $stmt->fetchColumn();
                echo $jsonResponse ? $jsonResponse : json_encode(['ok' => false, 'msg' => 'Respuesta vacía de BD']);
                break;

            default:
                http_response_code(405);
                echo json_encode(['ok' => false, 'msg' => 'Método no soportado']);
                break;
        }
    }
}
catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error de BD: ' . $e->getMessage()]);
} catch (Throwable $e) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error de PHP: ' . $e->getMessage()]);
}
