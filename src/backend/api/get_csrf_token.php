<?php
/**
 * ============================================================
 * API: GENERADOR DE TOKEN CSRF (get_csrf_token.php)
 * ============================================================
 * ENDPOINT: GET /api/get_csrf_token.php
 *
 * PROPÓSITO:
 * Genera un token CSRF criptográficamente seguro vinculado a
 * la sesión del usuario. El frontend debe incluir este token
 * en todas las peticiones de escritura (POST, PUT, DELETE).
 *
 * SEGURIDAD:
 * - generateCsrfToken() usa bin2hex(random_bytes(32))
 * - Token almacenado en $_SESSION para validación posterior
 * - Cada generación invalida el token anterior
 *
 * NOTA: Este archivo NO toca la BD directamente.
 * No requiere migración a PostgreSQL, pero se documenta
 * como parte del cierre del blindaje.
 * ============================================================
 */

require_once '../config.php';
require_once '../utils/security_utils.php';
header('Content-Type: application/json');

// Generación de token real vinculado a la sesión
$token = generateCsrfToken();

echo json_encode([
    "ok" => true,
    "csrf_token" => $token,
    "info" => "Token de seguridad activo"
]);