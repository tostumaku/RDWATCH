/**
 * ARCHIVO: js/utils.js
 * MÓDULO: Utilidades Globales y UI Base
 * Dependencias: config.js (API_CONFIG, API_BASE_SHOP)
 *
 * Contenido:
 *   - Constantes de API
 *   - Gestión de moneda y formatPrice()
 *   - Header scroll effect
 *   - Preloader
 *   - Cookie banner
 *   - Menú móvil (unificado, sin duplicados)
 */

// =========================================================
// 1. CONSTANTES GLOBALES
// =========================================================
const API_BASE = API_CONFIG.baseUrl;

// =========================================================
// 2. MONEDA Y FORMATO DE PRECIO
// =========================================================

// Globales de moneda (se cargan desde tab_Configuracion via API)
window.MONEDA_ACTIVA = 'COP';
window.TASA_CAMBIO = 1;

/**
 * Formatea un monto numérico según la moneda activa del sistema.
 * @param {number} amount - Monto a formatear
 * @returns {string} Monto formateado con símbolo de moneda
 */
function formatPrice(amount) {
    const moneda = window.MONEDA_ACTIVA || 'COP';
    const tasa = window.TASA_CAMBIO || 1;
    const locale = moneda === 'COP' ? 'es-CO' : 'en-US';
    const decimals = moneda === 'COP' ? 0 : 2;
    return Number(amount * tasa).toLocaleString(locale, {
        style: 'currency',
        currency: moneda,
        minimumFractionDigits: decimals,
        maximumFractionDigits: decimals,
    });
}

// Exponer formatPrice globalmente para todos los módulos
window.formatPrice = formatPrice;

// Cargar moneda activa desde la BD al arrancar
(async function initMoneda() {
    try {
        const r = await fetch(API_CONFIG.baseUrl + '/admin_settings.php', { credentials: 'include' });
        if (r.ok) {
            const d = await r.json();
            if (d.ok && d.store) {
                window.MONEDA_ACTIVA = d.store.moneda || 'COP';
                window.TASA_CAMBIO = Number(d.store.tasa_cambio) || 1;
            }
        }
    } catch (e) {
        console.warn('No se pudo cargar la configuración de moneda, usando COP por defecto.');
    }
})();

// =========================================================
// 3. INICIALIZACIÓN VISUAL GLOBAL
// =========================================================
document.addEventListener('DOMContentLoaded', () => {

    // --- Preloader ---
    const preloader = document.querySelector('.preloader');
    if (preloader) {
        setTimeout(() => {
            preloader.classList.add('fade-out');
            setTimeout(() => preloader.style.display = 'none', 500);
        }, 1000);
    }

    // --- Header scroll effect ---
    const header = document.querySelector('.header');
    if (header) {
        window.addEventListener('scroll', () => {
            if (window.scrollY > 50) header.classList.add('scrolled');
            else header.classList.remove('scrolled');
        });
    }

    // --- Cookie Banner ---
    const cookieBanner = document.getElementById('cookie-banner');
    const acceptBtn = document.getElementById('accept-cookies');

    if (cookieBanner && !localStorage.getItem('cookies_accepted')) {
        setTimeout(() => cookieBanner.classList.add('show'), 1500);
    }

    if (acceptBtn) {
        acceptBtn.addEventListener('click', () => {
            localStorage.setItem('cookies_accepted', 'true');
            cookieBanner.classList.remove('show');
        });
    }

    // --- Menú Móvil (Unificado) ---
    initMobileMenu();
});

// =========================================================
// 4. MENÚ MÓVIL (UNA SOLA IMPLEMENTACIÓN)
// =========================================================

/**
 * Inicializa el menú hamburguesa para dispositivos móviles.
 * Incluye: toggle, cierre al hacer clic en links, cierre al hacer clic fuera,
 * y clonación de acciones del header para la versión móvil.
 */
function initMobileMenu() {
    const mobileBtn = document.querySelector('.mobile-menu-btn');
    const mainNav = document.querySelector('.main-nav');
    if (!mobileBtn || !mainNav) return;

    // Clonar las acciones del header si existen (para mostrar "Mi Cuenta" en móvil)
    const headerActions = document.querySelector('.header-actions');
    if (headerActions && !mainNav.querySelector('.mobile-actions')) {
        const mobileActions = headerActions.cloneNode(true);
        mobileActions.classList.remove('header-actions');
        mobileActions.classList.add('mobile-actions');
        // Quitar ids para evitar duplicados en el DOM
        mobileActions.querySelectorAll('[id]').forEach(el => el.removeAttribute('id'));

        // Re-vincular eventos al modal de auth
        const loginBtn = mobileActions.querySelector('.btn-open-login, .button-secondary');
        if (loginBtn) {
            loginBtn.addEventListener('click', (e) => {
                e.preventDefault();
                const authModal = document.getElementById('auth-modal');
                if (authModal) {
                    authModal.style.display = 'flex';
                    setTimeout(() => authModal.classList.add('show'), 10);
                    mainNav.classList.remove('active');
                }
            });
        }

        mainNav.appendChild(mobileActions);

        // Si el usuario ya estaba logueado, actualizar el botón clonado
        const userState = sessionStorage.getItem('user');
        if (userState) {
            try {
                if (typeof updateHeaderUser === 'function') {
                    updateHeaderUser(JSON.parse(userState));
                }
            } catch (e) { /* silencio */ }
        }
    }

    // Toggle del menú
    mobileBtn.addEventListener('click', () => {
        const isActive = mainNav.classList.toggle('active');
        const icon = mobileBtn.querySelector('i');
        if (isActive) {
            icon.classList.remove('fa-bars');
            icon.classList.add('fa-times');
            document.body.style.overflow = 'hidden';
        } else {
            icon.classList.remove('fa-times');
            icon.classList.add('fa-bars');
            document.body.style.overflow = '';
        }

        if (headerActions) headerActions.classList.toggle('active', isActive);
    });

    // Cerrar menú al hacer clic en un enlace
    mainNav.querySelectorAll('.nav-link').forEach(link => {
        link.addEventListener('click', () => {
            mainNav.classList.remove('active');
            const icon = mobileBtn.querySelector('i');
            icon.classList.remove('fa-times');
            icon.classList.add('fa-bars');
            document.body.style.overflow = '';
            if (headerActions) headerActions.classList.remove('active');
        });
    });

    // Cerrar menú al hacer clic fuera
    document.addEventListener('click', (e) => {
        if (mainNav.classList.contains('active') &&
            !mainNav.contains(e.target) &&
            !mobileBtn.contains(e.target)) {
            mainNav.classList.remove('active');
            const icon = mobileBtn.querySelector('i');
            icon.classList.remove('fa-times');
            icon.classList.add('fa-bars');
            document.body.style.overflow = '';
            if (headerActions) headerActions.classList.remove('active');
        }
    });
}
