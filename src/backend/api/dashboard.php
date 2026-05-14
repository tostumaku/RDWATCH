<?php
header('Content-Type: application/json');
require_once '../config.php';

if (!isset($pdo)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error de configuración de BD']);
    exit;
}

try {
    // 1. Conteo de Productos
    $stmt = $pdo->query("SELECT COUNT(*) FROM tab_Productos");
    $totalProductos = $stmt->fetchColumn();

    // 2. Conteo de Clientes (excluyendo admins)
    $stmt = $pdo->query("SELECT COUNT(*) FROM tab_Usuarios WHERE rol != 'admin'");
    $totalClientes = $stmt->fetchColumn();

    // 3. Conteo de Servicios
    $stmt = $pdo->query("SELECT COUNT(*) FROM tab_Servicios");
    $totalServicios = $stmt->fetchColumn();

    // 4. Conteo de Pedidos
    $stmt = $pdo->query("SELECT COUNT(*) FROM tab_Orden");
    $totalPedidos = $stmt->fetchColumn();

    // 5. Datos para el Gráfico de Estados (Pedidos)
    // Agrupamos por estado_orden y contamos
    $stmt = $pdo->query("SELECT estado_orden, COUNT(*) as cantidad FROM tab_Orden GROUP BY estado_orden");
    $estadosData = $stmt->fetchAll(PDO::FETCH_KEY_PAIR); // Retorna ['pendiente' => 5, 'completado' => 10, etc.]

    // Normalizar estados para el frontend (asegurar que existan todos los keys o mandarlos dinámicos)
    // El frontend espera: pendiente, pagado, enviado, entregado, cancelado
    
    echo json_encode([
        'ok' => true,
        'stats' => [
            'productos' => $totalProductos,
            'clientes'  => $totalClientes,
            'servicios' => $totalServicios,
            'pedidos'   => $totalPedidos
        ],
        'chart' => $estadosData
    ]);

} catch (PDOException $e) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error de BD: ' . $e->getMessage()]);
}
