<?php
/**
 * ============================================================
 * API: ESTADÍSTICAS DEL DASHBOARD ADMINISTRATIVO (stats.php)
 * ============================================================
 * ENDPOINT: GET /api/stats.php
 *
 * PROPÓSITO:
 * Centraliza el cálculo de TODAS las métricas KPI del dashboard
 * administrativo y las estadísticas públicas del landing page.
 *
 * ACCESO: SOLO ADMIN (requireRole('admin'))
 *
 * FUNCIONES POSTGRESQL QUE USA:
 * - fn_stats_dashboard()    → JSON con 9 métricas (6 KPIs + 3 públicas)
 * - fn_stats_chart_data()   → JSON array [{estado, total}, ...]
 *
 * OPTIMIZACIÓN MASIVA:
 * Antes: 8 queries PHP separadas (6 conteos + JOIN reparados + satisfacción)
 * Ahora: 2 funciones PostgreSQL que consolidan todo internamente.
 *
 * MÉTRICAS QUE RETORNA:
 * - stats: productos, pedidos, clientes, servicios, ventas_monto, ventas_cant
 * - chart_data: {pendiente: N, confirmado: N, enviado: N, cancelado: N}
 * - public: years (desde 1972), repaired, satisfaction (%)
 * ============================================================
 */

header('Content-Type: application/json');
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');
require_once '../config.php';
require_once '../utils/security_utils.php';

// 🛡️ PROTECCIÓN DE MÉTRICAS: Solo accesible por admins
requireRole('admin');

if (!isset($pdo)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error de configuración de BD']);
    exit;
}

try {
    // ══════════════════════════════════════
    // 📊 MÉTRICAS KPI (todo en 1 llamada)
    // ══════════════════════════════════════
    // fn_stats_dashboard consolida 8 queries en 1 función
    $stmtStats = $pdo->prepare("SELECT fn_stats_dashboard()");
    $stmtStats->execute();
    $statsData = json_decode($stmtStats->fetchColumn(), true);

    // ══════════════════════════════════════
    // 📈 DATOS DE GRÁFICA (por estado)
    // ══════════════════════════════════════
    $stmtChart = $pdo->prepare("SELECT fn_stats_chart_data()");
    $stmtChart->execute();
    $chartRaw = json_decode($stmtChart->fetchColumn(), true);

    // Estructurar para el frontend (inicializar con ceros)
    $chartData = [
        'pendiente' => 0,
        'confirmado' => 0,
        'enviado' => 0,
        'cancelado' => 0
    ];

    // Mapear los resultados de la función
    foreach ($chartRaw as $row) {
        if (isset($chartData[$row['estado_orden']])) {
            $chartData[$row['estado_orden']] = (int)$row['total'];
        }
    }

    echo json_encode([
        'ok' => true,
        'stats' => [
            'productos' => (int)$statsData['productos'],
            'pedidos' => (int)$statsData['pedidos'],
            'clientes' => (int)$statsData['clientes'],
            'servicios' => (int)$statsData['servicios'],
            'ventas_monto' => (float)$statsData['ventas_monto'],
            'ventas_cant' => (int)$statsData['ventas_cant']
        ],
        'chart_data' => $chartData,
        // Estadísticas públicas para landing page
        'public' => [
            'years' => (int)$statsData['years'],
            'repaired' => (int)$statsData['repaired'],
            'satisfaction' => (int)$statsData['satisfaction']
        ]
    ]);

}
catch (PDOException $e) {
    http_response_code(500);
    error_log('[stats.php] ' . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.']);
}
