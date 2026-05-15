/**
 * ARCHIVO: js/auth.js
 * MÓDULO: Autenticación, Registro, Google OAuth y Gestión de Sesión
 * Dependencias: config.js, security.js, notifications.js, utils.js
 *
 * Contenido:
 *   - checkSession / updateHeaderUser
 *   - Login form handler
 *   - Signup form handler + validaciones en tiempo real
 *   - Forgot password form handler
 *   - Google Sign-In (UNIFICADO, sin duplicados)
 *   - Modal Auth (abrir/cerrar/tabs)
 *   - Toggle password visibility
 *   - Password strength meter
 */

// =========================================================
// 1. VARIABLE DE USUARIO ACTUAL
// =========================================================
let currentUser = null;

// =========================================================
// 2. GESTIÓN DE SESIÓN (HEADER)
// =========================================================

/**
 * Verifica si el usuario tiene sesión activa y actualiza el header.
 * También auto-rellena campos de envío si estamos en checkout.
 */
async function checkSession() {
    try {
        const res = await secureFetch(`${API_BASE_SHOP}/me.php`);
        const data = await res.json();

        if (data.ok && data.user) {
            currentUser = data.user;
            updateHeaderUser(data.user);

            // Auto-rellenar campo de dirección si estamos en checkout
            // NOTA: El select de ciudad se pre-selecciona desde checkout.js
            // después de cargar las opciones dinámicas (evita race condition).
            const addrInput = document.getElementById('shipping-address');
            if (addrInput && !addrInput.value) addrInput.value = data.user.direccion || '';

            // Guardar en sessionStorage para acceso rápido
            // Incluye departamento y id_departamento para que checkout.js
            // pueda pre-seleccionar los selects después de cargar opciones.
            sessionStorage.setItem('user', JSON.stringify(data.user));
        } else {
            sessionStorage.removeItem('user');
        }
    } catch (error) {
        console.error('Error verificando sesión:', error);
    }
}

/**
 * Actualiza los botones del header para mostrar el nombre del usuario logueado.
 * @param {Object} user - Objeto con datos del usuario (nombre, rol)
 */
function updateHeaderUser(user) {
    const loginBtns = document.querySelectorAll('#login-btn, .mobile-actions .button-secondary, .header-actions-mobile .button-secondary');
    if (!loginBtns.length) return;

    loginBtns.forEach(btn => {
        btn.innerHTML = `<i class="fas fa-user-circle"></i> ${user.nombre.split(' ')[0]}`;

        const newBtn = btn.cloneNode(true);
        btn.parentNode.replaceChild(newBtn, btn);

        newBtn.addEventListener('click', (e) => {
            e.preventDefault();
            const sessionUser = JSON.parse(sessionStorage.getItem('user'));
            if (sessionUser && sessionUser.rol === 'admin') {
                window.open(`${API_CONFIG.appUrl}/src/admin/admin.html`, '_blank');
            } else {
                window.open(`${API_CONFIG.appUrl}/src/user/user.html`, '_blank');
            }
        });
    });
}

// Exponer globalmente para que utils.js pueda usarla desde el menú móvil
window.updateHeaderUser = updateHeaderUser;

// =========================================================
// 3. FUNCIONES DE VALIDACIÓN REUTILIZABLES
// =========================================================

/**
 * Valida que el nombre solo contenga letras, espacios y acentos
 */
window.validateName = function (name) {
    const nameRegex = /^[a-zA-ZáéíóúÁÉÍÓÚñÑ\s]+$/;
    return nameRegex.test(name);
};

/**
 * Valida que el teléfono solo contenga números y tenga 10 dígitos
 */
window.validatePhone = function (phone) {
    const phoneRegex = /^\d{10}$/;
    return phoneRegex.test(phone);
};

/**
 * Valida los requisitos de contraseña
 * @returns {Object} - Objeto con los requisitos cumplidos
 */
window.validatePassword = function (password) {
    return {
        length: password.length >= 8,
        uppercase: /[A-Z]/.test(password),
        number: /[0-9]/.test(password),
        special: /[!@#$%^&*()_+\-=\[\]{};':"\\|,.<>\/?]/.test(password),
        isValid: function () {
            return this.length && this.uppercase && this.number && this.special;
        }
    };
};

// =========================================================
// 4. INICIALIZACIÓN (DOMContentLoaded)
// =========================================================

document.addEventListener('DOMContentLoaded', () => {

    // Verificar sesión al cargar
    checkSession();

    // Inicializar CSRF token si hay sesión
    const userLoggedIn = sessionStorage.getItem('user_logged_in');
    if (userLoggedIn === 'true') {
        fetchCsrfToken();
    }

    // --- Google Auth SDK ---
    initGoogleAuth();

    // =========================================================
    // 5. LOGIN FORM
    // =========================================================
    const loginForm = document.getElementById('loginForm');

    if (loginForm) {
        loginForm.addEventListener('submit', async function (e) {
            e.preventDefault();

            const emailInput = document.getElementById('login-email');
            const passwordInput = document.getElementById('login-password');
            const btnLogin = loginForm.querySelector('.btn-login');
            const btnText = btnLogin.querySelector('.btn-text');
            const btnLoader = btnLogin.querySelector('.btn-loader');

            if (btnText) btnText.style.display = 'none';
            if (btnLoader) btnLoader.style.display = 'inline-block';
            btnLogin.disabled = true;

            const email = emailInput.value.trim();
            const pass = passwordInput.value.trim();

            if (!email || !pass) {
                showNotification('⚠️ Por favor completa todos los campos', true);
                if (btnText) btnText.style.display = 'inline-block';
                if (btnLoader) btnLoader.style.display = 'none';
                btnLogin.disabled = false;
                return;
            }

            try {
                const response = await secureFetch(`${API_CONFIG.baseUrl}/login.php`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        email: emailInput.value,
                        password: passwordInput.value
                    })
                });

                const data = await response.json();

                if (data.ok) {
                    sessionStorage.setItem('user', JSON.stringify(data.user));
                    sessionStorage.setItem('user_logged_in', 'true');
                    showNotification('✅ Bienvenido ' + data.user.nombre);
                    updateHeaderUser(data.user);

                    setTimeout(() => {
                        if (data.redirect) {
                            const authModal = document.getElementById('auth-modal');
                            if (authModal) {
                                authModal.classList.remove('show');
                                setTimeout(() => authModal.style.display = 'none', 300);
                            }
                            window.open(`${API_CONFIG.appUrl}/${data.redirect}`, '_blank');
                        }
                    }, 1000);
                } else {
                    showNotification('❌ ' + (data.msg || 'Error al iniciar sesión'), true);
                }

            } catch (error) {
                console.error('Error login:', error);
                showNotification('Error de conexión con el servidor', true);
            } finally {
                if (btnText) btnText.style.display = 'inline-block';
                if (btnLoader) btnLoader.style.display = 'none';
                btnLogin.disabled = false;
            }
        });
    }

    // =========================================================
    // 6. FORGOT PASSWORD FORM
    // =========================================================
    const forgotForm = document.getElementById('forgotPasswordForm');
    if (forgotForm) {
        forgotForm.addEventListener('submit', async function (e) {
            e.preventDefault();

            const emailInput = document.getElementById('forgot-email');
            const btnSubmit = forgotForm.querySelector('button[type="submit"]');
            const btnText = btnSubmit.querySelector('.btn-text');
            const btnLoader = btnSubmit.querySelector('.btn-loader');

            if (btnText) btnText.style.display = 'none';
            if (btnLoader) btnLoader.style.display = 'inline-block';
            btnSubmit.disabled = true;

            try {
                const response = await secureFetch(`${API_CONFIG.baseUrl}/forgot_password.php`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({ email: emailInput.value.trim() })
                });

                const data = await response.json();

                if (data.ok) {
                    showNotification('✅ ' + data.msg);
                    forgotForm.reset();
                    setTimeout(() => {
                        const backBtn = document.getElementById('back-to-login');
                        if (backBtn) backBtn.click();
                    }, 3000);
                } else {
                    showNotification('❌ ' + (data.msg || 'Error al solicitar recuperación'), true);
                }
            } catch (error) {
                console.error('Error forgot password:', error);
                showNotification('Error de conexión con el servidor', true);
            } finally {
                if (btnText) btnText.style.display = 'inline-block';
                if (btnLoader) btnLoader.style.display = 'none';
                btnSubmit.disabled = false;
            }
        });
    }

    // =========================================================
    // 7. SIGNUP FORM
    // =========================================================
    const signupForm = document.getElementById('signupForm');

    if (signupForm) {
        signupForm.addEventListener('submit', async function (e) {
            e.preventDefault();

            const nameInput = document.getElementById('signup-name');
            const emailInput = document.getElementById('signup-email');
            const phoneInput = document.getElementById('signup-phone');
            const passInput = document.getElementById('signup-password');
            const confirmInput = document.getElementById('signup-password-confirm');

            const name = nameInput.value.trim();
            if (!validateName(name)) {
                showNotification('❌ El nombre solo debe contener letras y espacios', true);
                nameInput.focus();
                return;
            }

            const phone = phoneInput.value.trim();
            if (phone && !validatePhone(phone)) {
                showNotification('❌ El teléfono debe tener 10 dígitos numéricos', true);
                phoneInput.focus();
                return;
            }

            const password = passInput.value;
            const passwordRequirements = validatePassword(password);
            if (!passwordRequirements.isValid()) {
                let missingReqs = [];
                if (!passwordRequirements.length) missingReqs.push('8 caracteres');
                if (!passwordRequirements.uppercase) missingReqs.push('una mayúscula');
                if (!passwordRequirements.number) missingReqs.push('un número');
                if (!passwordRequirements.special) missingReqs.push('un carácter especial');

                showNotification('❌ La contraseña debe contener: ' + missingReqs.join(', '), true);
                passInput.focus();
                return;
            }

            if (passInput.value !== confirmInput.value) {
                showNotification('❌ Las contraseñas no coinciden', true);
                confirmInput.focus();
                return;
            }

            const btnSignup = signupForm.querySelector('.btn-signup');
            const btnText = btnSignup.querySelector('.btn-text');
            const btnLoader = btnSignup.querySelector('.btn-loader');

            if (btnText) btnText.textContent = "";
            if (btnLoader) btnLoader.style.display = 'inline-block';
            btnSignup.disabled = true;

            try {
                const API_URL = `${API_CONFIG.baseUrl}/signup.php`;
                const response = await secureFetch(API_URL, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        nombre: nameInput.value,
                        email: emailInput.value,
                        telefono: phoneInput.value,
                        password: passInput.value
                    })
                });

                const data = await response.json();

                if (response.ok && data.ok) {
                    showNotification('✅ Registro exitoso. Por favor inicia sesión.');
                    signupForm.reset();
                    const loginSwitcher = document.querySelector('.switcher-login');
                    if (loginSwitcher) loginSwitcher.click();
                } else {
                    const errorMsg = data.msg || 'Error al registrarse';
                    showNotification(`❌ ${errorMsg}`, true);
                }
            } catch (error) {
                console.error('Error signup:', error);
                showNotification('❌ Error de conexión al intentar registrarse', true);
            } finally {
                if (btnText) btnText.textContent = "CREAR CUENTA";
                if (btnLoader) btnLoader.style.display = 'none';
                btnSignup.disabled = false;
            }
        });
    }

    // =========================================================
    // 8. UI: TABS, TOGGLE PASSWORD, STRENGTH METER, MODAL
    // =========================================================

    // A. CAMBIO DE PESTAÑAS (LOGIN <-> REGISTRO)
    const switchers = document.querySelectorAll('.switcher');
    const forgotWrapper = document.getElementById('forgot-password-wrapper');
    const loginWrapper = document.querySelector('.form-login')?.parentElement;

    switchers.forEach(item => {
        item.addEventListener('click', function () {
            document.querySelectorAll('.form-wrapper').forEach(fw => {
                fw.classList.remove('is-active');
                if (fw.id === 'forgot-password-wrapper') {
                    fw.style.display = 'none';
                }
            });
            this.parentElement.style.display = '';
            this.parentElement.classList.add('is-active');
        });
    });

    // A2. ENLACES DE RECUPERACIÓN DE CONTRASEÑA
    const forgotPasswordLinks = document.querySelectorAll('.forgot-password');
    const backToLoginLinks = document.querySelectorAll('#back-to-login');

    forgotPasswordLinks.forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            document.querySelectorAll('.form-wrapper').forEach(fw => fw.classList.remove('is-active'));
            if (forgotWrapper) {
                forgotWrapper.style.display = 'block';
                setTimeout(() => forgotWrapper.classList.add('is-active'), 10);
            }
        });
    });

    backToLoginLinks.forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            document.querySelectorAll('.form-wrapper').forEach(fw => {
                fw.classList.remove('is-active');
                if (fw.id === 'forgot-password-wrapper') {
                    fw.style.display = 'none';
                }
            });
            if (loginWrapper) {
                loginWrapper.style.display = '';
                loginWrapper.classList.add('is-active');
            }
        });
    });

    // B. MOSTRAR/OCULTAR CONTRASEÑA (EL OJO)
    const togglePassBtns = document.querySelectorAll('.toggle-password');
    togglePassBtns.forEach(btn => {
        btn.addEventListener('click', (e) => {
            e.preventDefault();
            const input = btn.previousElementSibling;
            const icon = btn.querySelector('i');

            if (input.type === 'password') {
                input.type = 'text';
                icon.classList.remove('fa-eye');
                icon.classList.add('fa-eye-slash');
            } else {
                input.type = 'password';
                icon.classList.remove('fa-eye-slash');
                icon.classList.add('fa-eye');
            }
        });
    });

    // C. VALIDACIÓN EN TIEMPO REAL PARA NOMBRE (SIGNUP)
    const signupNameInput = document.getElementById('signup-name');
    const signupNameError = document.getElementById('signup-name-error');

    if (signupNameInput && signupNameError) {
        signupNameInput.addEventListener('input', function () {
            const value = this.value.trim();
            if (value && !validateName(value)) {
                signupNameError.textContent = 'Solo se permiten letras y espacios';
                signupNameError.style.display = 'block';
                signupNameError.style.color = '#e74c3c';
                this.style.borderColor = '#e74c3c';
            } else {
                signupNameError.textContent = '';
                signupNameError.style.display = 'none';
                this.style.borderColor = '';
            }
        });
    }

    // C2. VALIDACIÓN EN TIEMPO REAL PARA TELÉFONO (SIGNUP)
    const signupPhoneInput = document.getElementById('signup-phone');
    const signupPhoneError = document.getElementById('signup-phone-error');

    if (signupPhoneInput && signupPhoneError) {
        signupPhoneInput.addEventListener('keypress', function (e) {
            if (!/^\d$/.test(e.key) && e.key !== 'Backspace' && e.key !== 'Delete' && e.key !== 'Tab' && e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') {
                e.preventDefault();
            }
        });

        signupPhoneInput.addEventListener('input', function () {
            this.value = this.value.replace(/\D/g, '');
            const value = this.value;
            if (value && value.length < 10) {
                signupPhoneError.textContent = 'El teléfono debe tener 10 dígitos';
                signupPhoneError.style.display = 'block';
                signupPhoneError.style.color = '#e74c3c';
                this.style.borderColor = '#e74c3c';
            } else {
                signupPhoneError.textContent = '';
                signupPhoneError.style.display = 'none';
                this.style.borderColor = '';
            }
        });
    }

    // D. MEDIDOR DE FUERZA Y REQUISITOS DE CONTRASEÑA
    const passInputSignup = document.getElementById('signup-password');
    const strengthText = document.getElementById('strength-text');
    const bars = document.querySelectorAll('.strength-bar');

    const reqLength = document.getElementById('req-length');
    const reqUppercase = document.getElementById('req-uppercase');
    const reqNumber = document.getElementById('req-number');
    const reqSpecial = document.getElementById('req-special');

    if (passInputSignup && strengthText) {
        passInputSignup.addEventListener('input', function () {
            const val = this.value;
            const requirements = validatePassword(val);

            const updateRequirement = (element, met) => {
                if (!element) return;
                const icon = element.querySelector('i');
                if (met) {
                    element.style.color = '#2ecc71';
                    if (icon) {
                        icon.className = 'fas fa-check-circle';
                        icon.style.fontSize = '0.8rem';
                    }
                } else {
                    element.style.color = 'var(--text-muted)';
                    if (icon) {
                        icon.className = 'fas fa-circle';
                        icon.style.fontSize = '0.5rem';
                    }
                }
            };

            updateRequirement(reqLength, requirements.length);
            updateRequirement(reqUppercase, requirements.uppercase);
            updateRequirement(reqNumber, requirements.number);
            updateRequirement(reqSpecial, requirements.special);

            let score = 0;
            if (requirements.length) score++;
            if (requirements.uppercase) score++;
            if (requirements.number) score++;
            if (requirements.special) score++;

            const labels = ['Muy Débil', 'Débil', 'Media', 'Fuerte', 'Muy Segura'];
            strengthText.textContent = labels[score] || 'Muy Débil';

            bars.forEach((bar, idx) => {
                if (idx < score) {
                    if (score <= 1) bar.style.backgroundColor = '#e74c3c';
                    else if (score === 2) bar.style.backgroundColor = '#f1c40f';
                    else if (score === 3) bar.style.backgroundColor = '#3498db';
                    else bar.style.backgroundColor = '#2ecc71';
                } else {
                    bar.style.backgroundColor = '#ddd';
                }
            });
        });
    }

    // E. ABRIR/CERRAR MODAL AUTH
    const authModal = document.getElementById('auth-modal');
    const openBtns = document.querySelectorAll('#login-btn, .btn-open-login');
    const closeBtn = document.querySelector('.close-modal');

    if (authModal) {
        openBtns.forEach(btn => btn.addEventListener('click', (e) => {
            e.preventDefault();
            authModal.style.display = 'flex';
            setTimeout(() => authModal.classList.add('show'), 10);
        }));

        if (closeBtn) closeBtn.addEventListener('click', () => {
            authModal.classList.remove('show');
            setTimeout(() => authModal.style.display = 'none', 300);
        });

        authModal.addEventListener('click', (e) => {
            if (e.target === authModal) {
                authModal.classList.remove('show');
                setTimeout(() => authModal.style.display = 'none', 300);
            }
        });
    }
});

// =========================================================
// 9. GOOGLE AUTH (UNIFICADO)
// =========================================================

/**
 * Inicializa Google Sign-In SDK. Se reintenta si el SDK aún no ha cargado.
 */
function initGoogleAuth() {
    if (window._googleAuthInitialized) return;

    // Cargar el SDK si no está en el DOM
    if (!document.querySelector('script[src="https://accounts.google.com/gsi/client"]')) {
        const script = document.createElement('script');
        script.src = "https://accounts.google.com/gsi/client";
        script.async = true;
        script.defer = true;
        document.head.appendChild(script);
    }

    if (typeof google === 'undefined' || !google.accounts) {
        setTimeout(initGoogleAuth, 200);
        return;
    }

    window._googleAuthInitialized = true;

    google.accounts.id.initialize({
        client_id: '161765677969-t8kq1e2g5ol447aef763p5likq0enqed.apps.googleusercontent.com',
        callback: handleGoogleCallback,
        auto_select: false
    });

    // Renderizar botones de Google si existen en el DOM
    ['googleLogin', 'googleSignup'].forEach(id => {
        const btn = document.getElementById(id);
        if (btn && btn.parentElement) {
            const container = document.createElement('div');
            container.style.display = 'inline-block';
            btn.parentElement.insertBefore(container, btn);
            google.accounts.id.renderButton(container, {
                theme: 'outline', size: 'large', type: 'icon', shape: 'circle'
            });
            btn.style.display = 'none';
        }
    });
}

/**
 * Callback de Google Sign-In. Envía el credential al backend para autenticar.
 */
window.handleGoogleCallback = async function (response) {
    if (!response.credential) return;
    showNotification('Autenticando con Google...', false);
    try {
        const res = await secureFetch(`${API_CONFIG.baseUrl}/auth_google.php`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ credential: response.credential })
        });
        const data = await res.json();
        if (data.ok) {
            showNotification('✅ ' + data.msg);
            sessionStorage.setItem('user_logged_in', 'true');
            setTimeout(() => {
                if (data.data && data.data.role === 'admin') {
                    window.location.href = window.location.pathname.includes('/src/') ? 'admin/admin.html' : 'src/admin/admin.html';
                } else {
                    window.location.reload();
                }
            }, 1000);
        } else {
            showNotification('❌ ' + data.msg, true);
        }
    } catch (error) {
        console.error('Google Auth Error:', error);
        showNotification('Error de conexión al autenticar con Google.', true);
    }
};
