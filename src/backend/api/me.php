<?php
/**
 * ============================================================
 * API: VERIFICACIÓN DE IDENTIDAD (me.php)
 * ============================================================
 * ENDPOINT: GET /api/me.php
 *
 * PROPÓSITO:
 * El frontend llama a este endpoint al cargar la página para
 * saber QUIÉN está logueado. Si hay sesión activa, retorna
 * los datos del usuario. Si no, retorna que no hay sesión.
 *
 * FUNCIONES POSTGRESQL QUE USA:
 * - fn_auth_get_session(user_id) → JSON con perfil completo
 *   Internamente hace un JOIN triple:
 *   tab_Usuarios → tab_Direcciones_Envio → tab_Ciudades
 *   Para obtener: nombre, rol, dirección predeterminada y ciudad
 *
 * FLUJO COMPLETO:
 * 1. Verificar si hay sesión PHP activa ($_SESSION['logged_in'])
 * 2. Si SÍ: obtener user_id de la sesión
 * 3. Llamar fn_auth_get_session para obtener perfil completo
 * 4. Armar respuesta con datos del perfil
 * 5. Si NO hay sesión: retornar {ok: false, user: null}
 *
 * LÓGICA DE DIRECCIÓN:
 * Se prioriza direccion_completa (de tab_Direcciones_Envio),
 * pero si no existe, se usa direccion_principal (de tab_Usuarios).
 * Si ninguna existe, se muestra "Sin dirección registrada".
 * ============================================================
 */

require_once '../config.php';

header('Content-Type: application/json');
// Cache-Control previene que el navegador cachée esta respuesta
// (siempre debe consultar al servidor para tener datos frescos)
header('Cache-Control: no-store, no-cache, must-revalidate, max-age=0');
header('Pragma: no-cache');

// ──────────────────────────────────────────────
// VERIFICACIÓN: ¿HAY SESIÓN ACTIVA?
// ──────────────────────────────────────────────
// $_SESSION['logged_in'] se establece en login.php tras un login exitoso
if (isset($_SESSION['logged_in']) && $_SESSION['logged_in'] === true) {
    // Tomar el ID del usuario de la sesión PHP
    $userId = $_SESSION['user_id'];

    try {
        $stmt = $pdo->prepare("SELECT fn_auth_get_session(?::INTEGER)");
        $stmt->execute([$userId]);
        $jsonResult = $stmt->fetchColumn();

        if (!$jsonResult) {
            echo json_encode(["ok" => false, "msg" => "Usuario no encontrado en la base de datos"]);
            exit;
        }

        $userData = json_decode($jsonResult, true);

        // Validar que el JSON se decodificó correctamente
        if (!is_array($userData)) {
            echo json_encode(["ok" => false, "msg" => "Error al procesar datos del perfil"]);
            exit;
        }

        // PRIORIZACIÓN DE DIRECCIÓN (con nul-coalescing para evitar errores)
        $address = ($userData['direccion_completa'] ?? null) ?: (($userData['direccion_principal'] ?? null) ?: 'Sin dirección registrada');
        $city = ($userData['nombre_ciudad'] ?? null) ?: 'N/A';

        echo json_encode([
            "ok" => true,
            "user" => [
                "id" => $userData['id_usuario'] ?? $userId,
                "nombre" => $userData['nom_usuario'] ?? 'Usuario',
                "rol" => $userData['rol'] ?? 'cliente',
                "direccion" => $address,
                "ciudad" => $city
            ]
        ]);

    }
    catch (Throwable $e) {
        http_response_code(500);
    error_log('[me.php] ' . $e->getMessage());
    echo json_encode(['ok' => false, 'msg' => 'Ha ocurrido un error inesperado. Por favor, inténtalo de nuevo.']);
    }
}
else {
    // ──────────────────────────────────────────────
    // NO HAY SESIÓN: Usuario anónimo (no logueado)
    // ──────────────────────────────────────────────
    // Esto no es un error — el frontend lo usa para mostrar
    // botones de "Iniciar Sesión" en vez de "Mi Cuenta"
    echo json_encode([
        "ok" => false,
        "user" => null,
        "msg" => "Sesión no detectada o expirada"
    ]);
}
