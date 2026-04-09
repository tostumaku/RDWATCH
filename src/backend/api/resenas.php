<?php
/**
 * ============================================================
 * API: GESTIÓN DE RESEÑAS Y SOCIAL PROOF (resenas.php)
 * ============================================================
 * ENDPOINTS:
 *   GET  /api/resenas.php → Últimas 10 reseñas públicas
 *   POST /api/resenas.php → Crear nueva reseña (sesión requerida)
 *
 * PROPÓSITO:
 * Administra las opiniones y calificaciones de los clientes.
 * Genera confianza (social proof) mostrando testimonios reales
 * de otros compradores en la tienda.
 *
 * FUNCIONES POSTGRESQL QUE USA:
 * - fn_reviews_list()                  → JSON array (últimas 10)
 * - fn_reviews_create(uid, calif, com) → JSON {ok, msg, id}
 *   (incluye anti-duplicado y validación 1-5 internamente)
 *
 * SEGURIDAD:
 * - Listar reseñas: PÚBLICO (no requiere sesión)
 * - Crear reseña: requiere sesión + CSRF
 * - fn_reviews_create valida:
 *   1. Rango de calificación (1-5 estrellas)
 *   2. Anti-duplicado (misma persona, mismo comentario)
 * ============================================================
 */

require_once __DIR__ . '/../config.php';
require_once __DIR__ . '/../utils/security_utils.php';
require_once __DIR__ . '/../utils/Validation.php';
header('Content-Type: application/json');

if (!isset($pdo)) {
    http_response_code(500);
    echo json_encode(['ok' => false, 'msg' => 'Error técnico: El servidor de reputación no está disponible']);
    exit;
}

$method = $_SERVER['REQUEST_METHOD'];

try {
    if ($method === 'GET') {
        // ══════════════════════════════════════
        // 🔍 LISTAR RESEÑAS PÚBLICAS
        // ══════════════════════════════════════
        // fn_reviews_list hace JOIN interno con tab_Usuarios
        // para obtener el nombre del autor
        $stmt = $pdo->prepare("SELECT fn_reviews_list()");
        $stmt->execute();
        $resenas = json_decode($stmt->fetchColumn(), true);

        echo json_encode([
            "ok" => true,
            "count" => count($resenas),
            "resenas" => $resenas,
            "msg" => "Testimonios recuperados exitosamente"
        ]);
        exit;
    }

    if ($method === 'POST') {
        // ══════════════════════════════════════
        // ➕ ENVIAR NUEVA RESEÑA
        // ══════════════════════════════════════
        if (!isset($_SESSION['user_id'])) {
            http_response_code(401);
            echo json_encode(["ok" => false, "msg" => "Acceso restringido: Inicie sesión para compartir su experiencia"]);
            exit;
        }

        $id_usuario = $_SESSION['user_id'];
        validateCsrfToken(null, true);
        $input = getJsonInput();

        // Validación de inputs
        Validation::validateOrReject($input, [
            'calificacion' => 'numeric',
            'comentario' => 'address'
        ]);

        $calificacion = (int)$input['calificacion'];
        $comentario = Validation::sanitizeString($input['comentario']);

        // Validación de rango en PHP (defensa en profundidad)
        if ($calificacion < 1 || $calificacion > 5) {
            http_response_code(400);
            echo json_encode(["ok" => false, "msg" => "Calificación inválida: El rango permitido es de 1 a 5 estrellas"]);
            exit;
        }

        // fn_reviews_create incluye:
        // 1. Anti-duplicado interno
        // 2. Validación de rango (1-5)
        // 3. Auto-generación de ID
        // 4. Auditoría (usr_insert, fec_insert)
        $stmt = $pdo->prepare("SELECT fn_reviews_create(?::INTEGER, ?::smallint, ?)");
        $stmt->execute([$id_usuario, $calificacion, $comentario]);
        echo json_encode(json_decode($stmt->fetchColumn(), true));
        exit;
    }

    // Método no soportado
    http_response_code(405);
    echo json_encode(["ok" => false, "msg" => "Operación denegada en este endpoint de reseñas"]);

}
catch (PDOException $e) {
    http_response_code(500);
    error_log("PDOException en resenas.php: " . $e->getMessage());
    echo json_encode(["ok" => false, "msg" => "Error al procesar la reseña. Por favor intenta de nuevo."]);
}
catch (Exception $e) {
    http_response_code(500);
    error_log("Exception en resenas.php: " . $e->getMessage());
    echo json_encode(["ok" => false, "msg" => "Error inesperado en el servidor"]);
}