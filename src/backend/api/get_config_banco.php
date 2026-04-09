<?php
/**
 * ============================================================
 * API: CONFIGURACIÓN PARA PAGOS BANCARIOS (get_config_banco.php)
 * ============================================================
 * ENDPOINT: GET /api/get_config_banco.php
 *
 * PROPÓSITO:
 * Facilita al cliente los datos bancarios necesarios para
 * realizar transferencias durante el checkout.
 *
 * ACCESO: Solo usuarios autenticados (requireLogin)
 *
 * FUNCIÓN POSTGRESQL QUE USA:
 * - fn_config_get_bank() → JSON {nombre, tipo_cuenta, numero_cuenta, ...}
 *
 * ESTADO: Datos estáticos dentro de la función PostgreSQL.
 * En futuro se migrarán a tab_Config_Pagos para gestión dinámica.
 * Cuando se cree la tabla, SOLO se modifica la función SQL,
 * este PHP NO CAMBIA.
 * ============================================================
 */

header('Content-Type: application/json');
require_once '../config.php';
require_once '../utils/security_utils.php';

// 🛡️ Solo usuarios autenticados
requireLogin();

if (!isset($pdo)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error técnico: No se pudo cargar el motor de configuración']);
    exit;
}

try {
    // Consulta 100% opaca — los datos bancarios vienen de PostgreSQL
    $stmt = $pdo->prepare("SELECT fn_config_get_bank()");
    $stmt->execute();
    $bankData = json_decode($stmt->fetchColumn(), true);

    echo json_encode([
        'ok' => true,
        'banco' => $bankData
    ]);
}
catch (PDOException $e) {
    http_response_code(500);
    error_log('[get_config_banco.php] ' . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.']);
}
