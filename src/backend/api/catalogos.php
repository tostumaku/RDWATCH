<?php
/**
 * ============================================================
 * API: ASISTENTE DE CARGA PARA CATÁLOGOS / DROPDOWNS (catalogos.php)
 * ============================================================
 * ENDPOINT: GET /api/catalogos.php?tipo=marcas|categorias|subcategorias
 *
 * PROPÓSITO:
 * Provee listas simplificadas (ID + nombre) para poblar los
 * elementos <select> (dropdowns) del formulario de productos
 * en el panel de administración.
 *
 * DIFERENCIA CON LOS ENDPOINTS NORMALES:
 * - GET /api/marcas.php → retorna TODAS las marcas con TODOS sus campos
 * - GET /api/catalogos.php?tipo=marcas → solo marcas ACTIVAS, solo id+nombre
 * Los dropdowns son una versión filtrada y ligera de los datos completos.
 *
 * ENRUTAMIENTO:
 * Se usa ?tipo= como parámetro de query string para elegir qué catálogo:
 * - ?tipo=marcas        → Marcas activas
 * - ?tipo=categorias    → Categorías activas
 * - ?tipo=subcategorias → Subcategorías de UNA categoría (necesita ?id_categoria=X)
 *
 * FUNCIONES POSTGRESQL QUE USA:
 * - fn_cat_dropdown_marcas()              → JSON con marcas activas
 * - fn_cat_dropdown_categorias()          → JSON con categorías activas
 * - fn_cat_dropdown_subcategorias(id_cat) → JSON filtrado por categoría padre
 *
 * FLUJO FRONTEND:
 * 1. Admin abre formulario "Nuevo Producto"
 * 2. JavaScript llama /api/catalogos.php?tipo=marcas → pobla <select> marcas
 * 3. JavaScript llama /api/catalogos.php?tipo=categorias → pobla <select> categorías
 * 4. Admin selecciona categoría → JavaScript llama
 *    /api/catalogos.php?tipo=subcategorias&id_categoria=3
 *    → pobla <select> subcategorías de la categoría 3
 * ============================================================
 */

header('Content-Type: application/json');
// No cachear para que siempre retorne datos frescos
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');
require_once '../config.php';

if (!isset($pdo)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error de conexión: El catálogo maestro no está disponible']);
    exit;
}

// Leer qué tipo de catálogo se solicita desde la URL
// Por ejemplo: ?tipo=marcas → $tipo = 'marcas'
$tipo = $_GET['tipo'] ?? '';

try {
    switch ($tipo) {
        // ══════════════════════════════════════
        // DROPDOWN DE MARCAS ACTIVAS
        // ══════════════════════════════════════
        // fn_cat_dropdown_marcas solo retorna marcas donde estado_marca = TRUE
        // Ordenadas alfabéticamente por nombre
        case 'marcas':
            $stmt = $pdo->prepare("SELECT fn_cat_dropdown_marcas()");
            $stmt->execute();
            $data = json_decode($stmt->fetchColumn(), true);
            echo json_encode(['ok' => true, 'marcas' => $data]);
            break;

        // ══════════════════════════════════════
        // DROPDOWN DE CATEGORÍAS ACTIVAS
        // ══════════════════════════════════════
        // fn_cat_dropdown_categorias solo retorna categorías donde estado = TRUE
        case 'categorias':
            $stmt = $pdo->prepare("SELECT fn_cat_dropdown_categorias()");
            $stmt->execute();
            $data = json_decode($stmt->fetchColumn(), true);
            echo json_encode(['ok' => true, 'categorias' => $data]);
            break;

        // ══════════════════════════════════════
        // DROPDOWN DE SUBCATEGORÍAS (FILTRADO)
        // ══════════════════════════════════════
        // Este dropdown DEPENDE de la categoría que el admin seleccionó
        // Por eso necesita ?id_categoria=X en la URL
        // Al seleccionar categoría, el frontend recarga este dropdown
        case 'subcategorias':
            $idCat = isset($_GET['id_categoria']) ? $_GET['id_categoria'] : null;
            if (!$idCat) {
                // Sin id_categoria no podemos filtrar → error
                echo json_encode(['ok' => false, 'msg' => 'Entrada inválida: El ID de la categoría padre es requerido', 'subcategorias' => []]);
                exit;
            }
            // fn_cat_dropdown_subcategorias filtra por:
            // - id_categoria = $idCat (solo las de ESTA categoría)
            // - estado = TRUE (solo las activas)
            $stmt = $pdo->prepare("SELECT fn_cat_dropdown_subcategorias(?)");
            $stmt->execute([$idCat]);
            $data = json_decode($stmt->fetchColumn(), true);
            echo json_encode(['ok' => true, 'subcategorias' => $data]);
            break;

        default:
            // ?tipo= no reconocido o vacío
            echo json_encode(['ok' => false, 'msg' => 'Descriptor de catálogo no válido o no definido']);
            break;
    }
}
catch (PDOException $e) {
    http_response_code(500);
    error_log('[catalogos.php] ' . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.']);
}
