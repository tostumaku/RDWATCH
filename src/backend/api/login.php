<?php
/**
 * ============================================================
 * API: LOGIN DE USUARIO (login.php)
 * ============================================================
 * ENDPOINT: POST /api/login.php
 * 
 * PROPÓSITO:
 * Autentica al usuario verificando sus credenciales (email + contraseña).
 * Incluye protección anti-brute force mediante rate limiting.
 * 
 * PRINCIPIO DE OCULTACIÓN TOTAL:
 * Este archivo NO contiene ningún nombre de tabla ni columna de la BD.
 * Todas las consultas son opacas: "SELECT fn_algo(?)"
 * Los datos se reciben como JSON puro que PHP decodifica.
 * 
 * FUNCIONES POSTGRESQL QUE USA:
 * - fn_sec_check_rate_limit(ip, acción, límite, ventana) → BOOLEAN
 * - fn_auth_get_user(email) → JSON con datos del usuario
 * - fn_sec_log_attempt(ip, acción) → Registra intento fallido
 * - fn_sec_clear_attempts(ip, acción) → Limpia intentos tras éxito
 * - fn_auth_update_hash(id, hash) → Migra contraseña legacy a bcrypt
 * 
 * FLUJO COMPLETO:
 * 1. Verificar rate limiting (¿demasiados intentos fallidos?)
 * 2. Buscar usuario por email (fn_auth_get_user)
 * 3. Verificar si cuenta está activa y no bloqueada
 * 4. Comparar contraseña con hash bcrypt
 * 5. Si contraseña legacy: migrar automáticamente a bcrypt
 * 6. Si éxito: crear sesión PHP + limpiar intentos
 * 7. Si fallo: registrar intento fallido
 * ============================================================
 */

require_once '../config.php'; // Conexión PDO a PostgreSQL + configuración
require_once '../utils/security_utils.php'; // getJsonInput, getClientIP, validateCsrfToken, etc.
require_once '../utils/Validation.php'; // Sanitización de inputs

header('Content-Type: application/json');

// Asegurar que la sesión PHP esté activa
// session_status() verifica si ya hay sesión iniciada para no duplicarla
if (session_status() === PHP_SESSION_NONE) {
    session_start();
}

// Obtener los datos JSON que envió el frontend (email y password)
$input = getJsonInput();

// Obtener la IP real del cliente (para rate limiting)
$clientIP = getClientIP();

// ──────────────────────────────────────────────
// PASO 1: RATE LIMITING (Anti-Brute Force)
// ──────────────────────────────────────────────
// Llama a fn_sec_check_rate_limit con:
// - IP del cliente
// - Tipo de acción: 'login_attempt'
// - Límite: 5 intentos
// - Ventana: 15 minutos
// Retorna TRUE si puede continuar, FALSE si está bloqueado
$rlStmt = $pdo->prepare("SELECT fn_sec_check_rate_limit(?, ?, 5, 15)");
$rlStmt->execute([$clientIP, 'login_attempt']);
if (!$rlStmt->fetchColumn()) {
    // El usuario excedió 5 intentos en 15 minutos → bloqueado temporalmente
    http_response_code(429); // 429 = Too Many Requests
    echo json_encode(["ok" => false, "msg" => "Demasiados intentos fallidos. Por favor espere 15 minutos."]);
    exit;
}

// Sanitizar el email para prevenir inyecciones
$email = Validation::sanitizeString($input['email'] ?? '');
// La contraseña puede venir como 'password' o 'contra' (compatibilidad)
$pass = $input['password'] ?? ($input['contra'] ?? '');

try {
    // ──────────────────────────────────────────────
    // PASO 2: BUSCAR USUARIO (Consulta 100% Opaca)
    // ──────────────────────────────────────────────
    // fn_auth_get_user retorna JSON con: id, nombre, hash, rol, activo, bloqueado
    // PHPno sabe QUÉ columnas hay → solo decodifica el JSON
    // Si el email no existe → retorna NULL
    $stmt = $pdo->prepare("SELECT fn_auth_get_user(?)");
    $stmt->execute([$email]);
    $user = json_decode($stmt->fetchColumn(), true);

    // ──────────────────────────────────────────────
    // PASO 3: ¿USUARIO ENCONTRADO?
    // ──────────────────────────────────────────────
    if (!$user) {
        // No existe usuario con ese email → registrar intento fallido
        $pdo->prepare("SELECT fn_sec_log_attempt(?, ?)")->execute([$clientIP, 'login_attempt']);
        echo json_encode(["ok" => false, "msg" => "Las credenciales no coinciden con nuestros registros"]);
        exit;
    }

    // ──────────────────────────────────────────────
    // PASO 4: ¿CUENTA ACTIVA Y NO BLOQUEADA?
    // ──────────────────────────────────────────────
    if (!$user['activo']) {
        echo json_encode(["ok" => false, "msg" => "Cuenta desactivada. Contacte a soporte."]);
        exit;
    }
    if ($user['bloqueado']) {
        echo json_encode(["ok" => false, "msg" => "Cuenta bloqueada por seguridad. Contacte a soporte."]);
        exit;
    }

    // ──────────────────────────────────────────────
    // PASO 5: VERIFICAR CONTRASEÑA
    // ──────────────────────────────────────────────
    $loginSuccess = false;

    // CASO A: Contraseña bcrypt (moderno)
    // password_verify() compara la contraseña ingresada contra el hash bcrypt
    if (password_verify($pass, $user['contra'])) {
        $loginSuccess = true;
    }
    // CASO B: Contraseña legacy (texto plano)
    // Si password_verify falla pero la contraseña coincide en texto plano,
    // significa que el hash aún no se migró → se migra automáticamente
    elseif ($pass === $user['contra']) {
        // Generar nuevo hash bcrypt para reemplazar la contraseña plana
        $newHash = password_hash($pass, PASSWORD_BCRYPT);
        // fn_auth_update_hash actualiza la contraseña en la BD
        $pdo->prepare("SELECT fn_auth_update_hash(?, ?)")->execute([$user['id_usuario'], $newHash]);
        $loginSuccess = true;
    }

    // ──────────────────────────────────────────────
    // PASO 6: RESULTADO DEL LOGIN
    // ──────────────────────────────────────────────
    if ($loginSuccess) {
        // Asegurar sesión activa antes de regenerar
        if (session_status() === PHP_SESSION_NONE) {
            session_start();
        }
        // Regenerar ID de sesión para prevenir session fixation attacks
        session_regenerate_id(true);

        // Limpiar intentos fallidos de esta IP (perdón total)
        $pdo->prepare("SELECT fn_sec_clear_attempts(?, ?)")->execute([$clientIP, 'login_attempt']);

        // Guardar datos del usuario en la sesión PHP
        // Estos valores se usan en otros endpoints para saber quién está logueado
        $_SESSION['user_id'] = $user['id_usuario']; // ID numérico
        $_SESSION['user_role'] = $user['rol']; // 'admin' o 'cliente'
        $_SESSION['user_name'] = $user['nom_usuario']; // Nombre para UI
        $_SESSION['logged_in'] = true; // Flag de autenticación

        // Generar token CSRF para proteger las siguientes operaciones
        generateCsrfToken();

        // Mapear el panel correspondiente según el rol para la redirección automática
        $redirectUrl = ($user['rol'] === 'admin') ? 'src/admin/admin.html' : 'src/user/user.html';

        // Respuesta exitosa al frontend
        echo json_encode([
            "ok" => true,
            "msg" => "Bienvenido, " . $user['nom_usuario'],
            "user" => [
                "id" => $user['id_usuario'],
                "nombre" => $user['nom_usuario'],
                "rol" => $user['rol']
            ],
            "redirect" => $redirectUrl,
            "csrf_token" => $_SESSION['csrf_token'] // El frontend lo necesita para futuras peticiones
        ]);
    }
    else {
        // Contraseña incorrecta → registrar intento fallido para rate limiting
        $pdo->prepare("SELECT fn_sec_log_attempt(?, ?)")->execute([$clientIP, 'login_attempt']);
        echo json_encode(["ok" => false, "msg" => "La contraseña ingresada es incorrecta"]);
    }

}
catch (Throwable $e) {
    // Loguear el error técnico SOLO en el servidor (nunca exponerlo al cliente)
    error_log('[login.php] Error en autenticación: ' . $e->getMessage());
    http_response_code(500);
    echo json_encode(["ok" => false, "msg" => "Ocurrió un error al iniciar sesión. Por favor, inténtalo de nuevo."]);
}