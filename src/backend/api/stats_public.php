<?php
/**
 * GET /api/stats_public.php
 * Estadísticas públicas del landing: años, reparaciones, satisfacción.
 * ACCESO: Público (sin autenticación)
 */

header('Content-Type: application/json');
header('Cache-Control: public, max-age=300');

if ($_SERVER['REQUEST_METHOD'] !== 'GET') {
    http_response_code(405);
    echo json_encode(['ok' => false, 'msg' => 'Método no permitido']);
    exit;
}

require_once '../config.php';

if (!isset($pdo)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error de configuración de BD']);
    exit;
}

try {
    $data = json_decode($pdo->query("SELECT fn_stats_public()")->fetchColumn(), true);

    echo json_encode([
        'ok'     => true,
        'public' => [
            'years'        => (int)($data['years']        ?? 50),
            'repaired'     => (int)($data['repaired']     ?? 12000),
            'satisfaction' => (int)($data['satisfaction'] ?? 98),
        ]
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    error_log('[stats_public.php] ' . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Error al obtener estadísticas']);
}
