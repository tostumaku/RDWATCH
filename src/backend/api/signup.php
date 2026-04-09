<?php
/**
 * ============================================================
 * API: REGISTRO DE USUARIOS NUEVOS (signup.php)
 * ============================================================
 * ENDPOINT: POST /api/signup.php
 *
 * PROPÓSITO:
 * Permite a personas nuevas crear una cuenta de cliente.
 * La validación de duplicados se hace DENTRO de PostgreSQL,
 * no en PHP. Esto garantiza atomicidad (no hay race conditions).
 *
 * PRINCIPIO DE OCULTACIÓN TOTAL:
 * Solo se ejecuta: "SELECT fn_auth_register(?, ?, ?, ?)"
 * PHP no sabe QUÉ tablas existen ni CÓMO se valida.
 *
 * FUNCIONES POSTGRESQL QUE USA:
 * - fn_auth_register(nombre, email, teléfono, hash) → JSON
 *   Internamente esta función:
 *   1. Verifica duplicado por email
 *   2. Verifica duplicado por nombre+teléfono
 *   3. Auto-genera el siguiente ID
 *   4. Inserta con rol='cliente', activo=TRUE
 *   5. Retorna {ok: bool, msg: '...'}
 *
 * FLUJO COMPLETO:
 * 1. Validar token CSRF (protección anti-forgery)
 * 2. Validar formato del input (name, email, phone, password)
 * 3. Generar hash bcrypt de la contraseña
 * 4. Llamar fn_auth_register → deja que PostgreSQL valide TODO
 * 5. Reenviar respuesta JSON al frontend
 * ============================================================
 */

require_once '../config.php'; // Conexión PDO a PostgreSQL
require_once '../utils/security_utils.php'; // CSRF, getJsonInput
require_once '../utils/Validation.php'; // Validaciones de formato

header('Content-Type: application/json');

// ──────────────────────────────────────────────
// PASO 1: VALIDACIÓN CSRF
// ──────────────────────────────────────────────
// El segundo parámetro TRUE hace que acepte el token
// desde el header X-CSRF-Token (para peticiones AJAX)
validateCsrfToken(null, true);

// ──────────────────────────────────────────────
// PASO 2: OBTENER Y VALIDAR INPUT
// ──────────────────────────────────────────────
$input = getJsonInput();

// validateOrReject verifica que cada campo tenga el formato correcto:
// 'name' = texto no vacío, longitud razonable
// 'email' = formato email válido
// 'phone' = formato telefónico
// 'password' = longitud mínima 6 caracteres y complejidad
// Si alguno falla → lanza excepción → PHP responde con error 400
Validation::validateOrReject($input, [
    'nombre' => 'name',
    'email' => 'email',
    'telefono' => 'phone',
    'password' => 'password'
]);

try {
    // ──────────────────────────────────────────────
    // PASO 3: GENERAR HASH BCRYPT
    // ──────────────────────────────────────────────
    // password_hash() crea un hash seguro de la contraseña
    // PASSWORD_BCRYPT usa el algoritmo blowfish con 60 caracteres de output
    // NUNCA enviamos la contraseña en texto plano a PostgreSQL
    $pass = $input['password'];
    $hash = password_hash($pass, PASSWORD_BCRYPT);

    // ──────────────────────────────────────────────
    // PASO 4: REGISTRAR EN BASE DE DATOS
    // ──────────────────────────────────────────────
    // Consulta opaca: PHP envía 4 valores y recibe JSON
    // fn_auth_register hace TODAS las validaciones de duplicados internamente
    // Retorna SIEMPRE un JSON: {ok: true/false, msg: '...'}
    $stmt = $pdo->prepare("SELECT fn_auth_register(?, ?, ?, ?)");
    $stmt->execute([
        $input['nombre'], // Nombre completo
        $input['email'], // Correo electrónico
        $input['telefono'], // Teléfono (se convierte a BIGINT dentro de la función)
        $hash // Hash bcrypt de la contraseña
    ]);

    // ──────────────────────────────────────────────
    // PASO 5: REENVIAR RESPUESTA AL FRONTEND
    // ──────────────────────────────────────────────
    // json_decode convierte el string JSON de PostgreSQL en array PHP
    // Luego json_encode lo vuelve a serializar para el frontend
    // La respuesta ya viene formateada desde PostgreSQL
    $result = json_decode($stmt->fetchColumn(), true);
    echo json_encode($result);

}
catch (Throwable $e) {
    error_log('[signup.php] ' . $e->getMessage());
    http_response_code(500);
    echo json_encode([
        "ok" => false,
        "msg" => "Ocurrió un error en el registro. Por favor, inténtalo de nuevo."
    ]);
}