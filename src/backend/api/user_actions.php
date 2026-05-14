<?php
/**
 * ============================================================
 * API: ACCIONES DEL CLIENTE / PANEL DE USUARIO (user_actions.php)
 * ============================================================
 * ENDPOINTS:
 *   GET  ?action=perfil   → Datos personales del usuario
 *   GET  ?action=pedidos  → Historial de órdenes del cliente
 *   GET  ?action=resumen  → Dashboard con conteos rápidos
 *   POST action=update_profile  → Actualizar nombre/email/teléfono
 *   POST action=update_address  → Sincronizar dirección principal
 *
 * PROPÓSITO:
 * Centraliza todas las acciones que un cliente puede realizar
 * sobre su propia cuenta: consultar perfil, ver pedidos,
 * actualizar datos de contacto y gestionar dirección de envío.
 *
 * SEGURIDAD:
 * - requireLogin(): sesión obligatoria para toda operación
 * - IDOR Prevention: siempre se usa $_SESSION['user_id'],
 *   nunca el ID enviado por el cliente
 * - CSRF: validado en todas las operaciones de escritura (POST)
 *
 * FUNCIONES POSTGRESQL QUE USA:
 * - fn_user_get_profile(user_id)      → JSON con datos personales
 * - fn_user_get_orders(user_id)       → JSON array de pedidos
 * - fn_user_get_dashboard(user_id)    → JSON {activos, completados, citas}
 * - fn_user_update_profile(uid, nom, email, tel) → JSON {ok, msg}
 * - fn_user_update_address(uid, dir, ciudad, postal) → JSON {ok, msg}
 *
 * OPTIMIZACIÓN DE DASHBOARD:
 * Antes se hacían 3 queries PHP separadas para los conteos.
 * Ahora fn_user_get_dashboard hace los 3 conteos en 1 llamada.
 * ============================================================
 */

header('Content-Type: application/json');
require_once '../config.php';
require_once '../utils/security_utils.php';
require_once '../utils/Validation.php';

// 🛡️ SEGURIDAD: Se requiere inicio de sesión para CUALQUIER acción
requireLogin();

if (!isset($pdo)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error de configuración de BD']);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'];

try {
    if ($method === 'GET') {
        // ══════════════════════════════════════
        // 🔍 OBTENCIÓN DE DATOS (GET)
        // ══════════════════════════════════════
        // 🛡️ SEGURIDAD IDOR: Se ignora cualquier 'uid' de la URL
        $uid = $_SESSION['user_id'];
        $action = $_GET['action'] ?? '';

        if ($action === 'perfil') {
            // ── PERFIL PERSONAL ──
            // fn_user_get_profile retorna datos no sensibles
            // NUNCA expone contraseña ni tokens de reset
            $stmt = $pdo->prepare("SELECT fn_user_get_profile(?)");
            $stmt->execute([$uid]);
            $profile = json_decode($stmt->fetchColumn(), true);

            if (isset($profile['ok']) && $profile['ok'] === false) {
                echo json_encode($profile);
            }
            else {
                echo json_encode(['ok' => true, 'data' => $profile]);
            }

        }
        elseif ($action === 'pedidos') {
            // ── HISTORIAL DE PEDIDOS ──
            // fn_user_get_orders retorna array ordenado DESC
            $stmt = $pdo->prepare("SELECT fn_user_get_orders(?)");
            $stmt->execute([$uid]);
            $json = $stmt->fetchColumn() ?: '[]';
            echo '{"ok":true,"data":' . $json . '}';

        }
        elseif ($action === 'resumen') {
            // ── DASHBOARD RÁPIDO ──
            // fn_user_get_dashboard consolida 3 conteos en 1 llamada
            // Antes: 3 queries PHP → Ahora: 1 función PG
            $stmt = $pdo->prepare("SELECT fn_user_get_dashboard(?)");
            $stmt->execute([$uid]);
            $json = $stmt->fetchColumn() ?: '[]';
            echo '{"ok":true,"data":' . $json . '}';

        }
        else {
            echo json_encode(['ok' => false, 'msg' => 'Acción no especificada o inválida']);
        }

    }
    elseif ($method === 'POST') {
        // ══════════════════════════════════════
        // 🔄 PROCESAMIENTO DE ACCIONES (POST)
        // ══════════════════════════════════════
        validateCsrfToken(null, true);
        $data = getJsonInput();

        $action = $data['action'] ?? '';
        // 🛡️ SEGURIDAD IDOR: El ID NUNCA viene del cliente
        $uid = $_SESSION['user_id'];

        if ($action === 'update_profile' && $uid) {
            // ── ACTUALIZAR PERFIL ──
            // fn_user_update_profile incluye anti-duplicado de email
            Validation::validateOrReject($data, [
                'nombre' => 'name',
                'email' => 'email',
                'telefono' => 'phone'
            ]);

            $nombre = Validation::sanitizeString($data['nombre']);
            $email = Validation::sanitizeString($data['email']);
            $telefono = $data['telefono'];

            // Consulta 100% opaca
            $stmt = $pdo->prepare("SELECT fn_user_update_profile(?, ?, ?, ?)");
            $stmt->execute([$uid, $nombre, $email, $telefono]);
            $jsonResponse = $stmt->fetchColumn();
            echo $jsonResponse ? $jsonResponse : json_encode(['ok' => false, 'msg' => 'Respuesta vacía de BD']);

        }
        elseif ($action === 'update_address' && $uid) {
            // ── ACTUALIZAR DIRECCIÓN (ATÓMICA) ──
            // fn_user_update_address sincroniza Usuarios + Direcciones_Envio
            // internamente, anti-redundancia incluida
            Validation::validateOrReject($data, [
                'direccion' => 'address',
                'ciudad_id' => 'id',
                'postal' => 'zip'
            ]);

            $direccion = Validation::sanitizeString($data['direccion']);
            $ciudad_id = (int)$data['ciudad_id'];
            $postal = $data['postal'];

            // Consulta 100% opaca
            $stmt = $pdo->prepare("SELECT fn_user_update_address(?, ?, ?, ?)");
            $stmt->execute([$uid, $direccion, $ciudad_id, $postal]);
            $jsonResponse = $stmt->fetchColumn();
            echo $jsonResponse ? $jsonResponse : json_encode(['ok' => false, 'msg' => 'Respuesta vacía de BD']);

        }
        else {
            echo json_encode(['ok' => false, 'msg' => 'Acción POST no reconocida o datos incompletos']);
        }
    }
    else {
        http_response_code(405);
        echo json_encode(['ok' => false, 'msg' => 'Método HTTP no permitido']);
    }
}
catch (PDOException $e) {
    http_response_code(500);
    error_log('[user_actions.php] ' . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.']);
}
