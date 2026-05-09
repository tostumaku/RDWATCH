/**
 * RD Watch - Módulo de Seguridad Centralizado (CSRF)
 * Propósito: Unificar la comunicación segura con protección CSRF dinámico.
 * Tokens: Generados por sesión, criptográficamente seguros (bin2hex(random_bytes(32)))
 */

let csrfToken = null;

/**
 * Obtener token CSRF dinámico del servidor
 * Cada sesión obtiene un token único vinculado a su cookie de sesión
 */
async function fetchCsrfToken() {
    try {
        const res = await fetch(`${API_CONFIG.baseUrl}/get_csrf_token.php`, {
            method: 'GET',
            credentials: 'include'  // Enviar cookie de sesión
        });
        const data = await res.json();
        if (data.ok && data.token) {
            csrfToken = data.token;
            return csrfToken;
        } else {
            console.error('Failed to fetch CSRF token:', data);
            throw new Error('No se pudo obtener token CSRF del servidor');
        }
    } catch (error) {
        console.error('Error al obtener token CSRF:', error);
        throw error;
    }
}

/**
 * Wrapper de Fetch que inyecta automáticamente el token CSRF dinámico
 * Obtiene un token fresco del servidor si no lo tiene o si falla una petición con 419
 */
async function secureFetch(url, options = {}) {
    const method = options.method ? options.method.toUpperCase() : 'GET';

    // Para peticiones que modifican estado, necesitamos token CSRF
    if (['POST', 'PUT', 'DELETE', 'PATCH'].includes(method)) {
        // Obtener token si no lo tenemos
        if (!csrfToken) {
            await fetchCsrfToken();
        }

        options.headers = options.headers || {};
        options.headers['X-CSRF-Token'] = csrfToken;
    }

    // Siempre incluir credenciales (cookies de sesión)
    options.credentials = 'include';

    try {
        const response = await fetch(url, options);

        // Si recibimos 419 (CSRF inválido), refrescar token e intentar de nuevo
        if (response.status === 419) {
            console.warn('Token CSRF expirado, refrescando...');
            csrfToken = null;  // Limpiar token inválido

            if (['POST', 'PUT', 'DELETE', 'PATCH'].includes(method)) {
                await fetchCsrfToken();  // Obtener uno nuevo
                options.headers['X-CSRF-Token'] = csrfToken;
                return fetch(url, options);  // Reintentar
            }
        }

        return response;
    } catch (error) {
        console.error('Secure fetch error:', error);
        throw error;
    }
}

// Exponer funciones al ámbito global para compatibilidad con script.js, user.js y admin.js
window.secureFetch = secureFetch;
window.fetchCsrfToken = fetchCsrfToken;
