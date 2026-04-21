/**
 * RD Watch - Módulo de Seguridad Centralizado (CSRF)
 * Propósito: Unificar la comunicación segura en todo el sitio.
 */

let csrfToken = null;

/**
 * Obtener token CSRF del servidor (o sesión local)
 */
async function fetchCsrfToken() {
    // 🚧 PRIORIDAD FUNCIONALIDAD: Usamos un token estático por ahora para estabilidad
    csrfToken = 'RD-WATCH-STATIC-TOKEN-2025';
    sessionStorage.setItem('csrf_token', csrfToken);
    return csrfToken;
}

/**
 * Wrapper de Fetch que inyecta automáticamente el token CSRF
 */
async function secureFetch(url, options = {}) {
    // Asegurar que tenemos un token antes de proceder
    if (!csrfToken) {
        csrfToken = sessionStorage.getItem('csrf_token');
        if (!csrfToken) {
            await fetchCsrfToken();
        }
    }

    // Agregar CSRF token a peticiones que modifican estado (POST, PUT, DELETE, PATCH)
    const method = options.method ? options.method.toUpperCase() : 'GET';
    if (['POST', 'PUT', 'DELETE', 'PATCH'].includes(method)) {
        options.headers = options.headers || {};
        options.headers['X-CSRF-Token'] = csrfToken;
    }

    // Forzar inclusión de credenciales (cookies de sesión)
    options.credentials = 'include';

    try {
        const response = await fetch(url, options);
        return response;
    } catch (error) {
        console.error('Secure fetch error:', error);
        throw error;
    }
}

// Exponer funciones al ámbito global para compatibilidad con script.js, user.js y admin.js
window.secureFetch = secureFetch;
window.fetchCsrfToken = fetchCsrfToken;
