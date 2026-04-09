<?php
/**
 * ============================================================
 * API: GESTIÓN DE CITAS Y RESERVAS TÉCNICAS (citas.php)
 * ============================================================
 * ENDPOINTS:
 *   GET  /api/citas.php → Listar citas (vista cambia por rol)
 *   POST /api/citas.php → Crear cita O actualizar estado
 *   PUT  /api/citas.php → Actualizar estado (REST estándar)
 *
 * PROPÓSITO:
 * Gestiona la programación de servicios técnicos del taller.
 * Los clientes solicitan citas y los admins las gestionan.
 *
 * VISTA DUAL POR ROL:
 * - Admin: ve TODAS las citas con datos del cliente (fn_citas_list_admin)
 * - Cliente: solo ve SUS propias citas (fn_citas_list_cliente)
 *
 * FUNCIONES POSTGRESQL QUE USA:
 * - fn_citas_list_admin()                           → JSON array completo
 * - fn_citas_list_cliente(user_id)                  → JSON array filtrado
 * - fn_citas_create(user, servicio, fecha, prior, notas) → JSON {ok, msg}
 * - fn_citas_update_status(reserva_id, estado, admin_id)  → JSON {ok, msg}
 *
 * ANTI-DUPLICADO (dentro de fn_citas_create):
 * No permite crear 2 citas para el mismo servicio + fecha
 * si ya hay una pendiente. Esto se valida DENTRO de PostgreSQL.
 * ============================================================
 */

header('Content-Type: application/json');
require_once '../config.php';
require_once '../utils/Validation.php';
require_once '../utils/security_utils.php';

if (!isset($pdo)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error de configuración de BD']);
    exit;
}

// ──────────────────────────────────────────────
// SEGURIDAD: Sesión obligatoria
// ──────────────────────────────────────────────
if (!isset($_SESSION['user_id'])) {
    http_response_code(401);
    echo json_encode(['ok' => false, 'msg' => 'No autorizado: Inicie sesión para continuar']);
    exit;
}

$user_id = $_SESSION['user_id'];
$method = $_SERVER['REQUEST_METHOD'];
$rol = $_SESSION['user_role'] ?? 'cliente';

try {
    if ($method === 'GET') {
        // ══════════════════════════════════════
        // LISTAR CITAS (vista varía según rol)
        // ══════════════════════════════════════
        if ($rol === 'admin') {
            // Admin ve TODAS las citas con JOIN usuarios y servicios
            $stmt = $pdo->prepare("SELECT fn_citas_list_admin()");
            $stmt->execute();
            $citas = json_decode($stmt->fetchColumn(), true);

            // Admin también ve solicitudes del formulario de contacto
            $stmtC = $pdo->prepare("SELECT fn_contacto_list_admin()");
            $stmtC->execute();
            $contactos = json_decode($stmtC->fetchColumn(), true);

            echo json_encode(['ok' => true, 'citas' => $citas, 'contactos' => $contactos ?? []]);
        }
        else {
            // Cliente solo ve sus propias citas
            $stmt = $pdo->prepare("SELECT fn_citas_list_cliente(?::INTEGER)");
            $stmt->execute([$user_id]);
            $citas = json_decode($stmt->fetchColumn(), true);
            echo json_encode(['ok' => true, 'citas' => $citas]);
        }

    }
    elseif ($method === 'POST') {
        // ══════════════════════════════════════
        // SOLICITAR O ACTUALIZAR CITA
        // ══════════════════════════════════════
        validateCsrfToken(null, true);
        $data = getJsonInput();

        // SUB-ACCIÓN: update_status (compatibilidad POST)
        // Algunos frontends envían actualización de estado por POST
        if (isset($data['action']) && $data['action'] === 'update_status') {
            if ($rol !== 'admin') {
                http_response_code(403);
                echo json_encode(['ok' => false, 'msg' => 'Acción denegada: Solo administradores pueden cambiar estados']);
                exit;
            }

            Validation::validateOrReject($data, [
                'id_reserva' => 'id',
                'estado' => 'name'
            ]);

            // Llamada opaca
            $stmt = $pdo->prepare("SELECT fn_citas_update_status(?::INTEGER, ?, ?)");
            $stmt->execute([$data['id_reserva'], $data['estado'], 'admin_' . $user_id]);
            echo json_encode(json_decode($stmt->fetchColumn(), true));
            exit;
        }

        // ACCIÓN POR DEFECTO: Crear nueva cita
        Validation::validateOrReject($data, [
            'p_id_servicio' => 'id',
            'p_fecha_pref' => 'name',
            'p_prioridad' => 'name'
        ]);

        $id_servicio = (int)$data['p_id_servicio'];
        $fecha_pref = Validation::sanitizeString($data['p_fecha_pref']);
        $prioridad = Validation::sanitizeString($data['p_prioridad'] ?? 'normal');
        $notas = Validation::sanitizeString($data['p_notas'] ?? '');

        // fn_citas_create incluye anti-duplicado internamente
        $stmt = $pdo->prepare("SELECT fn_citas_create(?::INTEGER, ?::INTEGER, ?::date, ?, ?)");
        $stmt->execute([$user_id, $id_servicio, $fecha_pref, $prioridad, $notas]);
        echo json_encode(json_decode($stmt->fetchColumn(), true));

    }
    elseif ($method === 'PUT') {
        // ══════════════════════════════════════
        // ACTUALIZAR ESTADO (REST estándar)
        // ══════════════════════════════════════
        if ($rol !== 'admin') {
            http_response_code(403);
            echo json_encode(['ok' => false, 'msg' => 'No autorizado']);
            exit;
        }

        $data = getJsonInput();
        $id_reserva = Validation::validateNumeric($data['id_reserva'] ?? '') ? (int)$data['id_reserva'] : null;
        $nuevo_estado = Validation::sanitizeString($data['estado'] ?? '');

        if (!$id_reserva || empty($nuevo_estado)) {
            echo json_encode(['ok' => false, 'msg' => 'Faltan parámetros críticos (ID o Estado)']);
            exit;
        }

        $stmt = $pdo->prepare("SELECT fn_citas_update_status(?::INTEGER, ?, ?)");
        $stmt->execute([$id_reserva, $nuevo_estado, 'admin_' . $user_id]);
        echo json_encode(json_decode($stmt->fetchColumn(), true));

    }
    else {
        http_response_code(405);
        echo json_encode(['ok' => false, 'msg' => 'Método HTTP diseñado solo para GET, POST y PUT']);
    }
}
catch (Throwable $e) {
    http_response_code(500);
    error_log('[citas.php] ' . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.']);
}
