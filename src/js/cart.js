/**
 * ARCHIVO: js/cart.js
 * MÓDULO: Carrito de Compras (CRUD y UI)
 * Dependencias: config.js, security.js, notifications.js, utils.js (formatPrice)
 *
 * Contenido:
 *   - Estado del carrito (cart[])
 *   - addToCart, loadCart, updateCartQuantity, removeFromCart
 *   - toggleCart (abrir/cerrar sidebar)
 *   - updateCartDisplay (UI del sidebar)
 */

// =========================================================
// 1. ESTADO DEL CARRITO
// =========================================================
let cart = [];

// =========================================================
// 2. FUNCIONES GLOBALES (ACCESIBLES DESDE HTML onclick)
// =========================================================

/**
 * Abre/Cierra el carrito lateral
 */
window.toggleCart = function (forceOpen = false) {
    const sidebar = document.getElementById('cart-sidebar');
    const overlay = document.getElementById('cart-overlay');
    if (!sidebar) return;

    if (forceOpen === true || !sidebar.classList.contains('active')) {
        sidebar.classList.add('active');
        if (overlay) overlay.style.display = 'block';
        loadCart(); // Recargar datos al abrir
    } else {
        sidebar.classList.remove('active');
        if (overlay) overlay.style.display = 'none';
    }
};

// =========================================================
// 3. OPERACIONES CRUD CON EL BACKEND
// =========================================================

/**
 * Añade un producto al carrito vía API.
 * @param {number} productId - ID del producto
 * @param {number} quantity - Cantidad a añadir
 */
async function addToCart(productId, quantity) {
    // Validar stock local si los datos de tienda están disponibles
    if (typeof window._shopProductsData === 'function') {
        const products = window._shopProductsData();
        const product = products.find(p => p.id === productId);
        if (product && product.stock < quantity) {
            showNotification('Stock insuficiente', true);
            return;
        }
    }

    try {
        const res = await secureFetch(`${API_BASE_SHOP}/carrito.php`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id_producto: productId, cantidad: quantity })
        });

        if (res.status === 401) {
            showNotification('🔒 Inicia sesión para comprar', true);
            const modal = document.getElementById('auth-modal');
            if (modal) {
                modal.style.display = 'flex';
                setTimeout(() => modal.classList.add('show'), 10);
            }
            return;
        }

        const data = await res.json();

        if (data.ok) {
            showNotification('✅ Producto agregado');
            loadCart();
            window.toggleCart(true);
        } else {
            showNotification('❌ ' + (data.msg || 'Error'), true);
        }
    } catch (error) {
        console.error('Error addToCart:', error);
        showNotification('Error de conexión', true);
    }
}

// Exponer addToCart globalmente para shop.js
window.addToCart = addToCart;

/**
 * Carga los ítems del carrito desde la API.
 */
async function loadCart() {
    try {
        const res = await secureFetch(`${API_BASE_SHOP}/carrito.php`, {
            method: 'GET'
        });
        const data = await res.json();

        if (data.ok) {
            cart = data.items.map(item => ({
                id: parseInt(item.id_producto),
                name: item.nom_producto,
                price: parseFloat(item.precio),
                img: item.url_imagen || 'images/default-watch.png',
                quantity: parseInt(item.cantidad),
                stock: parseInt(item.stock)
            }));
            updateCartDisplay();
        }
    } catch (error) { console.error('Error loadCart:', error); }
}

/**
 * Actualizar cantidad de un producto en el carrito
 */
window.updateCartQuantity = async function (productId, newQty) {
    if (newQty < 1) return;

    const item = cart.find(i => i.id === productId);
    if (item && newQty > item.stock) {
        showNotification('Stock insuficiente', true);
        return;
    }

    try {
        const res = await secureFetch(`${API_BASE}/carrito.php`, {
            method: 'PUT',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id_producto: productId, cantidad: newQty })
        });
        const data = await res.json();

        if (data.ok) {
            await loadCart();
        } else {
            showNotification('❌ ' + data.msg, true);
        }
    } catch (error) {
        console.error('Error updateCartQuantity:', error);
    }
};

/**
 * Eliminar producto del carrito
 */
window.removeFromCart = async function (productId) {
    if (!await showConfirm('¿Eliminar este producto del carrito?', { danger: true, confirmText: 'Eliminar', cancelText: 'Cancelar' })) return;

    try {
        const res = await secureFetch(`${API_BASE}/carrito.php`, {
            method: 'DELETE',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id_producto: productId })
        });
        const data = await res.json();

        if (data.ok) {
            showNotification('🗑️ Producto eliminado');
            await loadCart();
        } else {
            showNotification('❌ ' + data.msg, true);
        }
    } catch (error) {
        console.error('Error removeFromCart:', error);
    }
};

// =========================================================
// 4. UI DEL CARRITO (SIDEBAR)
// =========================================================

function updateCartDisplay() {
    const list = document.getElementById('cart-items-list');
    const totalSpan = document.getElementById('cart-total');
    const subtotalSpan = document.getElementById('cart-subtotal');
    const checkoutBtn = document.getElementById('btn-procede-checkout');

    const countSpans = document.querySelectorAll('.cart-count'); // Selector unificado por clase

    let total = cart.reduce((acc, item) => acc + (item.price * item.quantity), 0);
    let qty = cart.reduce((acc, item) => acc + item.quantity, 0);

    countSpans.forEach(span => {
        span.textContent = qty;
        
        // Manejo de visibilidad: ocultar si es 0
        if (qty > 0) {
            span.style.display = 'inline-block';
            span.classList.add('pop-animation');
            setTimeout(() => span.classList.remove('pop-animation'), 300);
        } else {
            span.style.display = 'none';
        }
    });

    if (list) {
        if (cart.length === 0) {
            list.innerHTML = '<p class="empty-cart-message">Tu carrito está vacío</p>';
            if (checkoutBtn) checkoutBtn.disabled = true;
        } else {
            list.innerHTML = cart.map(item => `
                <div class="cart-item">
                    <img src="${item.img}" class="cart-item-img" onerror="this.src='https://via.placeholder.com/80'">
                    <div class="cart-item-details">
                        <h4>${item.name}</h4>
                        <p>${formatPrice(item.price)}</p>
                        <div class="cart-item-actions">
                            <div class="quantity-controls">
                                <button onclick="window.updateCartQuantity(${item.id}, ${item.quantity - 1})">-</button>
                                <span>${item.quantity}</span>
                                <button onclick="window.updateCartQuantity(${item.id}, ${item.quantity + 1})">+</button>
                            </div>
                            <button class="remove-item-btn" onclick="window.removeFromCart(${item.id})">
                                <i class="fas fa-trash"></i>
                            </button>
                        </div>
                    </div>
                </div>`).join('');
            if (checkoutBtn) checkoutBtn.disabled = false;
        }
    }

    if (subtotalSpan) subtotalSpan.textContent = formatPrice(total);
    if (totalSpan) totalSpan.textContent = formatPrice(total);
}

// Exponer para checkout.js
window._cartData = function () { return cart; };
window._cartUpdateDisplay = updateCartDisplay;
window._cartSetEmpty = function () { cart = []; updateCartDisplay(); };

// =========================================================
// 5. INICIALIZACIÓN
// =========================================================

document.addEventListener('DOMContentLoaded', () => {
    // Solo cargar carrito si el usuario tiene sesión activa (evita 401 para visitantes)
    if (sessionStorage.getItem('user_logged_in') === 'true') {
        loadCart();
    }
});
