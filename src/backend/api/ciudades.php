<?php
/**
 * ============================================================
 * API: DIVISIÓN TERRITORIAL / CATÁLOGO GEOGRÁFICO (ciudades.php)
 * ============================================================
 * ENDPOINTS:
 *   GET ?action=departamentos             → Listar departamentos
 *   GET ?action=ciudades&id_departamento=X → Ciudades de un depto
 *
 * PROPÓSITO:
 * Provee el catálogo geográfico (departamentos → ciudades)
 * para los dropdowns de dirección en checkout y panel de usuario.
 *
 * FUNCIONES POSTGRESQL QUE USA:
 * - fn_geo_departamentos()        → JSON array ordenado A-Z
 * - fn_geo_ciudades(depto_id)     → JSON array filtrado
 *
 * ACCESO: PÚBLICO (no requiere sesión).
 * Los datos geográficos no son sensibles.
 * ============================================================
 */

header('Content-Type: application/json');
require_once '../config.php';

if (!isset($pdo)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error técnico: El servicio de datos geográficos no está disponible']);
    exit;
}

$action = $_GET['action'] ?? '';

try {
    if ($action === 'departamentos') {
        // ══════════════════════════════════════
        // 🌐 OBTENER DEPARTAMENTOS
        // ══════════════════════════════════════
        $stmt = $pdo->prepare("SELECT fn_geo_departamentos()");
        $stmt->execute();
        $departamentos = json_decode($stmt->fetchColumn(), true);

        echo json_encode([
            'ok' => true,
            'count' => count($departamentos),
            'departamentos' => $departamentos
        ]);

    }
    elseif ($action === 'ciudades') {
        // ══════════════════════════════════════
        // 🏙️ OBTENER CIUDADES POR DEPARTAMENTO
        // ══════════════════════════════════════
        $id_depto = $_GET['id_departamento'] ?? null;
        if (!$id_depto) {
            echo json_encode(['ok' => false, 'msg' => 'Entrada inválida: Se requiere el identificador del departamento']);
            exit;
        }

        $stmt = $pdo->prepare("SELECT fn_geo_ciudades(?::INTEGER)");
        $stmt->execute([$id_depto]);
        $ciudades = json_decode($stmt->fetchColumn(), true);

        echo json_encode([
            'ok' => true,
            'count' => count($ciudades),
            'ciudades' => $ciudades
        ]);

    }
    else {
        echo json_encode(['ok' => false, 'msg' => 'Solicitud malformada: Acción geográfica no reconocida']);
    }
}
catch (PDOException $e) {
    http_response_code(500);
    error_log('[ciudades.php] ' . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.']);
}
