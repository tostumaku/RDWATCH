<?php
/**
 * ============================================================
 * API: GENERADOR DE TOKEN CSRF DINÁMICO (get_csrf_token.php)
 * ============================================================
 * ENDPOINT: GET /api/get_csrf_token.php
 *
 * PROPÓSITO:
 * Retorna un token CSRF criptográficamente seguro vinculado a
 * la sesión actual del usuario. El frontend incluye este token
 * automáticamente en todas las peticiones de escritura (POST, PUT, DELETE).
 *
 * SEGURIDAD:
 * - Genera token único: bin2hex(random_bytes(32)) = 64 caracteres hexadecimales
 * - Token almacenado en $_SESSION para validación posterior en validateCsrfToken()
 * - Cada sesión obtiene su propio token único
 * - Token se regenera tras login/logout y session_regenerate_id()
 *
 * VALIDACIÓN:
 * - Endpoint valida contra la cookie de sesión del cliente (credentials: include)
 * - El token es timing-safe: usa hash_equals() para prevenir timing attacks
 * - Si el token falla: HTTP 419 (Token Expired)
 *
 * NOTA: Este archivo NO toca la BD directamente.
 * ============================================================
 */

require_once '../config.php';
require_once '../utils/security_utils.php';
header('Content-Type: application/json');

// Generar token único criptográfico vinculado a la sesión
// Si ya existe uno en la sesión, lo reutiliza; si no, genera uno nuevo
$token = generateCsrfToken();

echo json_encode([
    "ok" => true,
    "token" => $token
]);