/**
 * ARCHIVO: js/checkout.js
 * MÓDULO: Pasarela de Pago (Checkout)
 * Dependencias: config.js, security.js, notifications.js, utils.js (formatPrice), cart.js (cart state)
 *
 * Contenido:
 *   - procedeToCheckout / backToCart
 *   - updateCheckoutSummary
 *   - Carga de departamentos y ciudades
 *   - Validación y envío del formulario de pago
 */

// =========================================================
// 1. NAVEGACIÓN CHECKOUT ↔ TIENDA
// =========================================================

/**
 * Ir a la pantalla de Pago (Checkout)
 */
window.procedeToCheckout = function () {
    const cart = window._cartData();
    if (!cart || cart.length === 0) {
        showNotification('Tu carrito está vacío.', true);
        return;
    }

    // 1. Cerrar sidebar
    const sidebar = document.getElementById('cart-sidebar');
    const overlay = document.getElementById('cart-overlay');
    if (sidebar) sidebar.classList.remove('active');
    if (overlay) overlay.style.display = 'none';

    // 2. Cambiar de pantalla
    const shopSection = document.querySelector('.shop-section');
    const checkoutSection = document.getElementById('checkout-section');
    const floatBtn = document.getElementById('floating-cart-btn');

    if (shopSection) shopSection.classList.add('hidden-section');
    if (checkoutSection) checkoutSection.classList.remove('hidden-section');
    if (floatBtn) floatBtn.style.display = 'none';

    // 3. Actualizar resumen
    updateCheckoutSummary();
    window.scrollTo({ top: 0, behavior: 'smooth' });
};

/**
 * Volver a la tienda desde el Checkout
 */
window.backToCart = function () {
    const shopSection = document.querySelector('.shop-section');
    const checkoutSection = document.getElementById('checkout-section');
    const floatBtn = document.getElementById('floating-cart-btn');

    if (checkoutSection) checkoutSection.classList.add('hidden-section');
    if (shopSection) shopSection.classList.remove('hidden-section');
    if (floatBtn) floatBtn.style.display = 'flex';

    window.toggleCart(true); // Reabrir carrito
};

// =========================================================
// 2. RESUMEN DE LA ORDEN
// =========================================================

function updateCheckoutSummary() {
    const summaryList = document.getElementById('checkout-order-summary');
    if (!summaryList) return;

    const cart = window._cartData();
    const SHIPPING_COST = 15000;
    let subtotal = cart.reduce((sum, item) => sum + (item.price * item.quantity), 0);

    summaryList.innerHTML = cart.map(item => `
        <div class="cart-item">
            <img src="${item.img}" class="cart-item-img" onerror="this.src='https://via.placeholder.com/80'">
            <div class="cart-item-details">
                <h4>${item.name}</h4>
                <p>${formatPrice(item.price)} x ${item.quantity}</p>
            </div>
        </div>
    `).join('');

    const elSub = document.getElementById('checkout-subtotal');
    const elShip = document.getElementById('checkout-shipping');
    const elTotal = document.getElementById('checkout-final-total');
    const elPay = document.getElementById('payment-amount');

    if (elSub) elSub.textContent = formatPrice(subtotal);
    if (elShip) elShip.textContent = formatPrice(SHIPPING_COST);
    if (elTotal) elTotal.textContent = formatPrice(subtotal + SHIPPING_COST);
    if (elPay) elPay.textContent = formatPrice(subtotal + SHIPPING_COST);
}

// =========================================================
// 3. DEPARTAMENTOS Y CIUDADES (SELECT DINÁMICO)
// =========================================================

async function cargarDepartamentosCheckout() {
    try {
        const response = await secureFetch(`${API_BASE_SHOP}/ciudades.php?action=departamentos`);
        const result = await response.json();
        if (result.ok) {
            const selectDepto = document.getElementById('shipping-depto');
            if (selectDepto) {
                selectDepto.innerHTML = '<option value="">Seleccione departamento...</option>' +
                    result.departamentos.map(d => `<option value="${d.id_departamento}">${d.nombre_departamento}</option>`).join('');

                selectDepto.addEventListener('change', (e) => {
                    const idDepto = e.target.value;
                    if (idDepto) cargarCiudadesCheckoutPorDepto(idDepto);
                    else {
                        const selectCiudad = document.getElementById('shipping-city');
                        if (selectCiudad) {
                            selectCiudad.innerHTML = '<option value="">Primero seleccione Dpto.</option>';
                            selectCiudad.disabled = true;
                        }
                    }
                });

                // ── PRE-SELECCIONAR DIRECCIÓN GUARDADA ──
                // Tras cargar las opciones del select, verificamos si el usuario
                // tiene una dirección guardada en sessionStorage (puesta por me.php → auth.js).
                try {
                    const userData = JSON.parse(sessionStorage.getItem('user'));
                    if (userData && userData.id_departamento) {
                        selectDepto.value = userData.id_departamento;
                        // Cargar ciudades y pre-seleccionar la ciudad guardada
                        if (userData.ciudad) {
                            await cargarCiudadesCheckoutPorDepto(userData.id_departamento);
                            const selectCiudad = document.getElementById('shipping-city');
                            if (selectCiudad) selectCiudad.value = userData.ciudad;
                        }
                        // Pre-llenar dirección si no fue llenada por auth.js
                        const addrInput = document.getElementById('shipping-address');
                        if (addrInput && !addrInput.value && userData.direccion) {
                            addrInput.value = userData.direccion;
                        }
                    }
                } catch (e) { /* sessionStorage vacío o inválido, no hacer nada */ }
            }
        }
    } catch (error) {
        console.error('Error al cargar departamentos checkout:', error);
    }
}

async function cargarCiudadesCheckoutPorDepto(idDepartamento) {
    try {
        const response = await secureFetch(`${API_BASE_SHOP}/ciudades.php?action=ciudades&id_departamento=${idDepartamento}`);
        const result = await response.json();
        if (result.ok) {
            const selectCiudad = document.getElementById('shipping-city');
            if (selectCiudad) {
                selectCiudad.innerHTML = '<option value="">Seleccione ciudad...</option>' +
                    result.ciudades.map(c => `<option value="${c.nombre_ciudad}">${c.nombre_ciudad}</option>`).join('');
                selectCiudad.disabled = false;
            }
        }
    } catch (error) {
        console.error('Error al cargar ciudades checkout:', error);
    }
}

// =========================================================
// 4. FORMULARIO DE PAGO (SUBMIT + VALIDACIÓN)
// =========================================================

const paymentForm = document.getElementById('payment-form');
if (paymentForm) {

    // Evitar que el navegador guarde el archivo cargado si el usuario usa el botón "Atrás"
    window.addEventListener('pageshow', (e) => {
        const proofInput = document.getElementById('payment-proof');
        if (proofInput) proofInput.value = '';
    });

    paymentForm.addEventListener('submit', async function (e) {
        e.preventDefault();

        const address = document.getElementById('shipping-address').value.trim();
        const city = document.getElementById('shipping-city').value.trim();
        const proofFile = document.getElementById('payment-proof').files[0];

        // === VALIDACIÓN DE DIRECCIÓN Y CIUDAD ===
        if (!address || address.length < 5) {
            showNotification('❌ Por favor ingresa una dirección válida (mínimo 5 caracteres)', true);
            document.getElementById('shipping-address').focus();
            return;
        }

        if (!city || city.length < 3) {
            showNotification('❌ Por favor ingresa una ciudad válida (mínimo 3 caracteres)', true);
            document.getElementById('shipping-city').focus();
            return;
        }

        // === VALIDACIÓN DE COMPROBANTE DE PAGO ===
        if (!proofFile) {
            showNotification('❌ Por favor adjunta el comprobante de pago', true);
            return;
        }

        // Validar tipo MIME y extensión
        const allowedMimeTypes = ['image/jpeg', 'image/png', 'image/svg+xml'];
        const allowedExtensions = ['.jpg', '.jpeg', '.png', '.svg'];

        const fileName = proofFile.name.toLowerCase();
        const fileExtension = fileName.substring(fileName.lastIndexOf('.'));

        if (!allowedMimeTypes.includes(proofFile.type) || !allowedExtensions.includes(fileExtension)) {
            showNotification('❌ El comprobante debe ser una imagen (JPG, PNG o SVG)', true);
            document.getElementById('payment-proof').value = '';
            return;
        }

        // Validar tamaño (máximo 5MB)
        const maxSize = 5 * 1024 * 1024;
        if (proofFile.size > maxSize) {
            showNotification('❌ El comprobante no debe superar los 5MB', true);
            document.getElementById('payment-proof').value = '';
            return;
        }

        const submitBtn = this.querySelector('button[type="submit"]');
        const btnText = submitBtn.querySelector('.btn-text');
        const btnLoader = submitBtn.querySelector('.btn-loader');

        if (btnText) btnText.style.display = 'none';
        if (btnLoader) btnLoader.style.display = 'inline-block';
        submitBtn.disabled = true;

        showNotification('🔄 Procesando orden y archivo...', false);

        const formData = new FormData();
        formData.append('direccion', address);
        formData.append('ciudad', city);
        formData.append('metodo', 'Consignación Bancaria');
        formData.append('payment_proof', proofFile);

        try {
            const res = await secureFetch(`${API_BASE_SHOP}/checkout.php`, {
                method: 'POST',
                body: formData
            });

            const data = await res.json();

            if (data.ok) {
                showNotification('✅ ¡Orden creada exitosamente!');
                window._cartSetEmpty();
                paymentForm.reset();

                const orderId = data.order_id;

                setTimeout(() => {
                    window.location.href = `factura.html?orden=${orderId}`;
                }, 1000);
            } else {
                showNotification('❌ ' + data.msg, true);
                if (btnText) btnText.style.display = 'inline-block';
                if (btnLoader) btnLoader.style.display = 'none';
                submitBtn.disabled = false;
            }
        } catch (error) {
            console.error(error);
            showNotification('Error de conexión', true);
            if (btnText) btnText.style.display = 'inline-block';
            if (btnLoader) btnLoader.style.display = 'none';
            submitBtn.disabled = false;
        }
    });
}

// =========================================================
// 5. INICIALIZACIÓN
// =========================================================

document.addEventListener('DOMContentLoaded', () => {
    cargarDepartamentosCheckout();
});
