<?php
/**
 * ============================================================
 * API: GESTIÓN DE SERVICIOS TÉCNICOS / TALLER (servicios.php)
 * ============================================================
 * ENDPOINTS:
 *   GET    /api/servicios.php → Listar todos los servicios
 *   POST   /api/servicios.php → Crear nuevo servicio
 *   PUT    /api/servicios.php → Actualizar servicio existente
 *   DELETE /api/servicios.php → Eliminar servicio (con protección)
 *
 * PROPÓSITO:
 * CRUD de los servicios técnicos del taller de relojería.
 * Son diferentes a los productos: los servicios se RESERVAN
 * (tab_Reservas), no se compran. Ejemplo:
 * - "Cambio de batería" → $25.000
 * - "Restauración completa" → $150.000
 * - "Ajuste de correa" → $15.000
 *
 * PERMISOS:
 * - GET: público (cualquiera puede ver servicios disponibles)
 * - POST/PUT/DELETE: solo admin
 *
 * FUNCIONES POSTGRESQL QUE USA:
 * - fn_cat_get_servicios()                              → JSON array
 * - fn_cat_create_servicio(id,nom,desc,precio,dur,usr)  → JSON {ok, msg}
 * - fn_cat_update_servicio(id,nom,desc,precio,dur)      → JSON {ok, msg}
 * - fn_cat_delete_servicio(id)                          → JSON con protección
 *
 * PROTECCIÓN AL BORRAR:
 * fn_cat_delete_servicio verifica si el servicio tiene reservas/citas
 * vinculadas en tab_Reservas. Si hay citas → no se puede borrar.
 * ============================================================
 */

header('Content-Type: application/json');
require_once '../config.php';
require_once '../utils/security_utils.php';
require_once '../utils/Validation.php';

if (!isset($pdo)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error de conexión: El motor de base de datos no responde']);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'];

try {
    switch ($method) {
        // ══════════════════════════════════════
        // GET: LISTAR TODOS LOS SERVICIOS
        // ══════════════════════════════════════
        // fn_cat_get_servicios retorna: id, nombre, descripción, precio, duración
        // Ordenados por ID descendente (más recientes primero)
        case 'GET':
            $stmt = $pdo->prepare("SELECT fn_cat_get_servicios()");
            $stmt->execute();
            $servicios = json_decode($stmt->fetchColumn(), true);
            echo json_encode(['ok' => true, 'servicios' => $servicios]);
            break;

        // ══════════════════════════════════════
        // POST: CREAR NUEVO SERVICIO
        // ══════════════════════════════════════
        // fn_cat_create_servicio valida internamente que no exista otro
        // servicio con el mismo nombre (anti-duplicado)
        case 'POST':
            requireRole('admin');
            validateCsrfToken(null, true);

            $data = getJsonInput();
            Validation::validateOrReject($data, [
                'id_servicio' => 'id', // ID numérico
                'nom_servicio' => 'name', // Nombre no vacío
                'precio_servicio' => 'price' // Precio positivo
            ]);

            // Campos opcionales con valores por defecto
            $desc = Validation::sanitizeString($data['descripcion'] ?? '');
            $duracion = Validation::sanitizeString($data['duracion_estimada'] ?? 'Consultar');
            $user_id = $_SESSION['user_id'] ?? 'admin_manual'; // Auditoría

            $stmt = $pdo->prepare("SELECT fn_cat_create_servicio(?, ?, ?, ?, ?, ?)");
            $stmt->execute([$data['id_servicio'], $data['nom_servicio'], $desc, $data['precio_servicio'], $duracion, $user_id]);
            echo json_encode(json_decode($stmt->fetchColumn(), true));
            break;

        // ══════════════════════════════════════
        // PUT: ACTUALIZAR SERVICIO
        // ══════════════════════════════════════
        case 'PUT':
            requireRole('admin');
            validateCsrfToken(null, true);

            $data = getJsonInput();
            if (!isset($data['id_servicio'])) {
                echo json_encode(['ok' => false, 'msg' => 'Error: Se requiere el ID del servicio para actualizar']);
                exit;
            }

            $stmt = $pdo->prepare("SELECT fn_cat_update_servicio(?, ?, ?, ?, ?, ?)");
            $stmt->execute([
                $data['id_servicio'],
                $data['nom_servicio'],
                $data['descripcion'],
                $data['precio_servicio'],
                $data['duracion_estimada'],
                isset($data['estado']) ? (bool)$data['estado'] : true
            ]);
            echo json_encode(json_decode($stmt->fetchColumn(), true));
            break;

        // ══════════════════════════════════════
        // DELETE: SOFT DELETE DE SERVICIO (CON PROTECCIÓN)
        // ══════════════════════════════════════
        // fn_cat_delete_servicio verifica reservas ACTIVAS (pendiente/confirmada):
        // - Si hay N citas activas → "Este servicio tiene N citas activas..."
        // - Si hay 0 citas activas → marca estado=FALSE, registra usr_delete y fec_delete
        case 'DELETE':
            requireRole('admin');
            validateCsrfToken(null, true);

            $data = getJsonInput();
            $sid = $data['id_servicio'] ?? null;

            // Logging de auditoría: registrar intento de soft delete
            logDebug("SOFT DELETE SERVICE ATTEMPT: ID[" . ($sid ?? 'NULL') . "]");

            if (!$sid) {
                echo json_encode(['ok' => false, 'msg' => 'ID de servicio no proporcionado']);
                exit;
            }

            $stmt = $pdo->prepare("SELECT fn_cat_delete_servicio(?::BIGINT)");
            $stmt->execute([$sid]);
            $result = json_decode($stmt->fetchColumn(), true);

            echo json_encode($result);
            break;

        default:
            http_response_code(405);
            echo json_encode(['ok' => false, 'msg' => 'Método HTTP no soportado por esta API']);
            break;
    }
}
catch (Throwable $e) {
    http_response_code(500);
    error_log('[servicios.php] ' . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.']);
}
