/**
 * RD Watch - Configuración Global Frontend
 */
const API_CONFIG = {
    // Detectar si estamos en un subdirectorio
    get baseUrl() {
        if (window.location.protocol === 'file:') return 'http://localhost/backend/api';

        const path = window.location.pathname;
        let projectRoot = '';

        // Buscar el segmento /src/ en la URL para determinar la raíz
        const srcIndex = path.indexOf('/src/');

        if (srcIndex !== -1) {
            projectRoot = path.substring(0, srcIndex);
        } else {
            // Fallback: Si no hay /src/, asumimos que estamos en el directorio actual
            projectRoot = path.substring(0, path.lastIndexOf('/'));
        }

        // Limpieza de barras
        if (projectRoot === '/') projectRoot = '';

        // Construcción dinámica basada en el host actual (IP, Dominio o Localhost)
        return window.location.origin + projectRoot + '/src/backend/api';
    },

    // Nueva propiedad para saber dónde está la raíz pública del frontend
    get appUrl() {
        if (window.location.protocol === 'file:') return 'http://localhost/';

        const path = window.location.pathname;
        let projectRoot = '';
        const srcIndex = path.indexOf('/src/');

        if (srcIndex !== -1) {
            projectRoot = path.substring(0, srcIndex);
        } else {
            projectRoot = path.substring(0, path.lastIndexOf('/'));
        }

        if (projectRoot === '/') projectRoot = '';
        return window.location.origin + projectRoot;
    }
};
// Convertimos los getters en propiedades estáticas para compatibilidad
Object.defineProperty(API_CONFIG, 'baseUrl', { value: API_CONFIG.baseUrl });
Object.defineProperty(API_CONFIG, 'appUrl', { value: API_CONFIG.appUrl });

// Alerta preventiva si se detecta acceso por archivo local
if (window.location.protocol === 'file:') {
    console.error("RD Watch: Estás accediendo vía file://. Para que el sistema funcione correctamente, usa http://localhost:8000");
}

// Alias para compatibilidad con código legado (script.js)
const API_BASE_SHOP = API_CONFIG.baseUrl;
