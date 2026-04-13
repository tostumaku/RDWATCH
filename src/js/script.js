/**
 * ARCHIVO: js/script.js
 * Versión Final: Funciones globales para botones HTML + Lógica de BD
 * SECURITY: Includes CSRF protection and input validation
 */

// La seguridad (csrfToken, secureFetch) ahora se gestiona en security.js

// =========================================================
// 1. CONFIGURACIÓN Y ESTADO GLOBAL
// =========================================================
const API_BASE = API_CONFIG.baseUrl;

let productsData = [];
let filteredData = [];
let cart = [];

const ITEMS_PER_PAGE = 9;
let currentPage = 1;

// =========================================================
// 2. FUNCIONES DE UTILIDAD
// =========================================================


// Globales de moneda (se cargan desde tab_Configuracion via API)
window.MONEDA_ACTIVA = 'COP';
window.TASA_CAMBIO = 1;

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
})()

// =========================================================
// 3. FUNCIONES GLOBALES (ACCESIBLES DESDE HTML)
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

/**
 * Ir a la pantalla de Pago (Checkout)
 */
window.procedeToCheckout = function () {
    if (cart.length === 0) {
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
// 4. LÓGICA DE DATOS (Backend)
// =========================================================

async function addToCart(productId, quantity) {
    // 1. Validar Stock local
    const product = productsData.find(p => p.id === productId);
    if (product && product.stock < quantity) {
        showNotification('Stock insuficiente', true);
        return;
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

    // Optimismo UI: Actualizar localmente primero para rapidez
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
            await loadCart(); // Esperar a que recargue
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
        // Optimismo UI: Ocultar el elemento visualmente de inmediato
        const res = await secureFetch(`${API_BASE}/carrito.php`, {
            method: 'DELETE',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ id_producto: productId })
        });
        const data = await res.json();

        if (data.ok) {
            showNotification('🗑️ Producto eliminado');
            await loadCart(); // Forzar recarga de datos
        } else {
            showNotification('❌ ' + data.msg, true);
        }
    } catch (error) {
        console.error('Error removeFromCart:', error);
    }
};

function updateCartDisplay() {
    // 1. Identificar elementos UI
    const list = document.getElementById('cart-items-list');
    const totalSpan = document.getElementById('cart-total');
    const subtotalSpan = document.getElementById('cart-subtotal');
    const checkoutBtn = document.getElementById('btn-procede-checkout');

    // Contadores (pueden ser varios: header, floating btn, etc)
    const countSpans = document.querySelectorAll('.cart-count, #cart-item-count');

    // 2. Cálculos base
    let total = cart.reduce((acc, item) => acc + (item.price * item.quantity), 0);
    let qty = cart.reduce((acc, item) => acc + item.quantity, 0);

    // 3. Actualizar contadores (Independiente de si hay lista o no)
    countSpans.forEach(span => {
        span.textContent = qty;
        // Efecto visual opcional si cambia
        span.classList.add('pop-animation');
        setTimeout(() => span.classList.remove('pop-animation'), 300);
    });

    // 4. Si estamos en una página con lista de carrito (sidebar o checkout)
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

function updateCheckoutSummary() {
    const summaryList = document.getElementById('checkout-order-summary');
    if (!summaryList) return;

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
// 5. CARGA DE PRODUCTOS (CATÁLOGO)
// =========================================================

async function loadProducts() {
    const productList = document.getElementById('product-list');
    if (!productList) return;

    try {
        productList.innerHTML = '<div style="grid-column:1/-1;text-align:center;padding:20px">Cargando...</div>';

        const [resProd, resCat] = await Promise.all([
            secureFetch(`${API_BASE}/productos.php`),
            secureFetch(`${API_BASE}/catalogos.php?tipo=categorias`)
        ]);

        const dataProd = await resProd.json();
        const dataCat = await resCat.json();

        if (dataCat.ok) renderCategoriesSidebar(dataCat.categorias);

        if (dataProd.ok) {
            productsData = dataProd.productos.map(p => ({
                id: parseInt(p.id_producto),
                name: p.nom_producto,
                description: p.descripcion || 'Sin descripción.',
                price: parseFloat(p.precio),
                stock: parseInt(p.stock),
                category: String(p.nom_categoria || 'General'),
                brand: String(p.nom_marca || 'General'),
                img: p.url_imagen || 'images/default-watch.png',
                badge: (p.stock < 5 && p.stock > 0) ? '¡Pocas!' : ''
            }));

            populateBrandFilter(productsData);

            // Los campos de precio mínimo y máximo inician vacíos, sin filtrar por defecto.

            filteredData = [...productsData];
            renderPaginatedProducts();
        } else {
            productList.innerHTML = `<p>Error: ${dataProd.msg}</p>`;
        }
    } catch (error) {
        console.error(error);
        productList.innerHTML = '<p>Error de conexión.</p>';
    }
}

function renderCategoriesSidebar(categorias) {
    const container = document.getElementById('category-filters');
    if (!container) return;
    let html = '<li><a href="#" data-filter="all" class="active category-link">Todos</a></li>';
    categorias.forEach(cat => {
        html += `<li><a href="#" data-filter="${cat.nom_categoria}" class="category-link">${cat.nom_categoria}</a></li>`;
    });
    container.innerHTML = html;

    document.querySelectorAll('.category-link').forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            document.querySelectorAll('.category-link').forEach(l => l.classList.remove('active'));
            e.target.classList.add('active');
            applyFilters();
        });
    });
}

function renderPaginatedProducts() {
    const productList = document.getElementById('product-list');
    if (!productList) return;

    if (filteredData.length === 0) {
        productList.innerHTML = '<div style="grid-column:1/-1;text-align:center;padding:20px">No hay productos.</div>';
        return;
    }

    const totalItems = filteredData.length;
    const totalPages = Math.ceil(totalItems / ITEMS_PER_PAGE);
    if (currentPage > totalPages) currentPage = 1;

    const startIndex = (currentPage - 1) * ITEMS_PER_PAGE;
    const pageItems = filteredData.slice(startIndex, startIndex + ITEMS_PER_PAGE);

    productList.innerHTML = pageItems.map(p => `
        <div class="product-card">
            <div class="product-image-container">
                <img src="${p.img}" alt="${p.name}" class="product-image" onerror="this.src='https://via.placeholder.com/250'">
                ${p.badge ? `<span class="product-badge">${p.badge}</span>` : ''}
            </div>
            <div class="product-details">
                <p class="product-category">${p.brand} - ${p.category}</p>
                <h3 class="product-name">${p.name}</h3>
                <p class="product-price">${formatPrice(p.price)}</p>
                <div class="product-actions">
                    ${p.stock > 0
            ? `<button class="button button-primary btn-add-cart" data-id="${p.id}"><i class="fas fa-cart-plus"></i> Añadir</button>`
            : `<button class="button button-secondary" disabled>Agotado</button>`
        }
                    <button class="button button-outline btn-view-product" data-id="${p.id}"><i class="fas fa-eye"></i> Ver</button>
                </div>
            </div>
        </div>
    `).join('');

    // Actualizar controles paginación
    const pageInfo = document.getElementById('page-info');
    const prevBtn = document.getElementById('prev-page');
    const nextBtn = document.getElementById('next-page');
    if (pageInfo) pageInfo.textContent = `Página ${currentPage} de ${totalPages || 1}`;
    if (prevBtn) {
        prevBtn.disabled = currentPage === 1;
        prevBtn.onclick = () => { currentPage--; renderPaginatedProducts(); window.scrollTo({ top: 0, behavior: 'smooth' }); };
    }
    if (nextBtn) {
        nextBtn.disabled = currentPage === totalPages || totalPages === 0;
        nextBtn.onclick = () => { currentPage++; renderPaginatedProducts(); window.scrollTo({ top: 0, behavior: 'smooth' }); };
    }
}

// Filtros y Buscadores
function applyFilters() {
    if (productsData.length === 0) return;
    const activeCatLink = document.querySelector('#category-filters .active');
    const activeCategory = activeCatLink ? activeCatLink.getAttribute('data-filter') : 'all';

    const brand = document.getElementById('brand-filter').value;
    const minPriceInput = document.getElementById('price-min') ? document.getElementById('price-min').value : '';
    const maxPriceInput = document.getElementById('price-max') ? document.getElementById('price-max').value : '';
    const minPrice = minPriceInput ? parseFloat(minPriceInput) : 0;
    const maxPrice = maxPriceInput ? parseFloat(maxPriceInput) : Infinity;
    const sortOrder = document.getElementById('sort-order').value;

    // 1. Filtrar
    filteredData = productsData.filter(p => {
        const matchCat = activeCategory === 'all' || p.category === activeCategory;
        const matchBrand = brand === 'all' || p.brand === brand;
        const matchPrice = p.price >= minPrice && p.price <= maxPrice;
        return matchCat && matchBrand && matchPrice;
    });

    // 2. Ordenar
    switch (sortOrder) {
        case 'price-asc':
            filteredData.sort((a, b) => a.price - b.price);
            break;
        case 'price-desc':
            filteredData.sort((a, b) => b.price - a.price);
            break;
        case 'name-asc':
            filteredData.sort((a, b) => a.name.localeCompare(b.name));
            break;
        case 'featured':
        default:
            filteredData.sort((a, b) => b.id - a.id);
            break;
    }

    currentPage = 1;
    renderPaginatedProducts();
}


function populateBrandFilter(products) {
    const brandSelect = document.getElementById('brand-filter');
    if (!brandSelect) return;
    while (brandSelect.options.length > 1) { brandSelect.remove(1); }
    const brands = [...new Set(products.map(p => p.brand))].sort();
    brands.forEach(b => {
        const opt = document.createElement('option');
        opt.value = b; opt.textContent = b;
        brandSelect.appendChild(opt);
    });
}

function openProductModal(id) {
    const product = productsData.find(p => p.id === id);
    if (!product) return;

    document.getElementById('modal-img').src = product.img;
    document.getElementById('modal-title').textContent = product.name;
    document.getElementById('modal-price').textContent = formatPrice(product.price);
    document.getElementById('modal-desc').textContent = product.description;

    // Actualizar marca dinámicamente
    const brandContainer = document.querySelector('#modal-brand span');
    if (brandContainer) brandContainer.textContent = product.brand;

    // Actualizar stock dinámicamente
    const stockContainer = document.getElementById('modal-stock');
    if (stockContainer) stockContainer.textContent = 'Stock: ' + product.stock;

    const qtyInput = document.getElementById('modal-qty');
    qtyInput.value = 1; qtyInput.max = product.stock;

    const addBtn = document.getElementById('modal-add-btn');
    const newBtn = addBtn.cloneNode(true);
    addBtn.parentNode.replaceChild(newBtn, addBtn);

    newBtn.onclick = () => {
        addToCart(product.id, parseInt(qtyInput.value));
        document.getElementById('product-detail-modal').style.display = 'none';
    };

    const modal = document.getElementById('product-detail-modal');
    modal.style.display = 'flex';
    setTimeout(() => modal.classList.add('active'), 10);
}

// =========================================================
// 6. PASARELA DE PAGO (CHECKOUT)
// =========================================================

// 🌆 Cargar departamentos y ciudades en Checkout
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
                // Mantenemos el value como el nombre de la ciudad porque el checkout lo envía en texto plano
                selectCiudad.innerHTML = '<option value="">Seleccione ciudad...</option>' +
                    result.ciudades.map(c => `<option value="${c.nombre_ciudad}">${c.nombre_ciudad}</option>`).join('');
                selectCiudad.disabled = false;
            }
        }
    } catch (error) {
        console.error('Error al cargar ciudades checkout:', error);
    }
}

document.addEventListener('DOMContentLoaded', () => {
    cargarDepartamentosCheckout();
});

// Lógica de UI para métodos de pago
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
        const maxSize = 5 * 1024 * 1024; // 5MB
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

        // Usar FormData para permitir envío de archivos
        const formData = new FormData();
        formData.append('direccion', address);
        formData.append('ciudad', city);
        formData.append('metodo', 'Consignación Bancaria');
        formData.append('payment_proof', proofFile);

        try {
            const res = await secureFetch(`${API_BASE_SHOP}/checkout.php`, {
                method: 'POST',
                body: formData // No enviamos headers de Content-Type, el navegador lo pone con el boundary
            });

            const data = await res.json();

            if (data.ok) {
                showNotification('✅ ¡Orden creada exitosamente!');
                cart = [];
                updateCartDisplay();
                paymentForm.reset(); // Limpiar el formulario y el input de archivo

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
// 7. INICIALIZACIÓN GLOBAL (Event Listeners)
// =========================================================


function initGalleryCarousel() {
    const track = document.getElementById('gallery-track');
    if (!track) return;

    const slides = Array.from(track.children);
    const nextBtn = document.querySelector('.gallery-btn.next');
    const prevBtn = document.querySelector('.gallery-btn.prev');

    if (slides.length === 0) return;

    let currentIndex = 0;

    const handleVideoAutoplay = () => {
        slides.forEach((slide, index) => {
            const video = slide.querySelector('video');
            if (video) {
                if (index === currentIndex) {
                    video.play().catch(e => console.warn('Autoplay prevented', e));
                } else {
                    video.pause();
                }
            }
        });
    };

    const updateSlidePosition = () => {
        track.style.transform = `translateX(-${currentIndex * 100}%)`;
        handleVideoAutoplay();
    };

    if (nextBtn) {
        nextBtn.addEventListener('click', () => {
            currentIndex = (currentIndex + 1) % slides.length;
            updateSlidePosition();
        });
    }

    if (prevBtn) {
        prevBtn.addEventListener('click', () => {
            currentIndex = (currentIndex - 1 + slides.length) % slides.length;
            updateSlidePosition();
        });
    }

    // Usar IntersectionObserver para reproducir el video inicial cuando sea visible
    const observer = new IntersectionObserver((entries) => {
        entries.forEach(entry => {
            if (entry.isIntersecting) {
                handleVideoAutoplay();
            } else {
                slides.forEach(slide => {
                    const video = slide.querySelector('video');
                    if (video) video.pause();
                });
            }
        });
    }, { threshold: 0.5 });
    
    // Observamos la sección de la galería
    const section = document.getElementById('gallery-section');
    if(section) observer.observe(section);
}

document.addEventListener('DOMContentLoaded', () => {
    // Inicializar visuales
    const preloader = document.querySelector('.preloader');
    if (preloader) setTimeout(() => { preloader.classList.add('fade-out'); setTimeout(() => preloader.style.display = 'none', 500); }, 1000);

    const header = document.querySelector('.header');
    if (header) window.addEventListener('scroll', () => { if (window.scrollY > 50) header.classList.add('scrolled'); else header.classList.remove('scrolled'); });

    // Inicializar Carrusel de Galería
    initGalleryCarousel();

    // SECURITY: Inicializar CSRF token si hay sesión
    const userLoggedIn = sessionStorage.getItem('user_logged_in');
    if (userLoggedIn === 'true') {
        fetchCsrfToken();
    }

    // Inicializar Tienda
    if (document.getElementById('product-list')) {
        loadProducts();
        document.getElementById('brand-filter')?.addEventListener('change', applyFilters);
        document.getElementById('price-min')?.addEventListener('input', applyFilters);
        document.getElementById('price-max')?.addEventListener('input', applyFilters);
        document.getElementById('sort-order')?.addEventListener('change', applyFilters);
        document.querySelector('.close-product-modal')?.addEventListener('click', () => {
            document.getElementById('product-detail-modal').style.display = 'none';
        });
    }

    // Auth Modal
    const authModal = document.getElementById('auth-modal');
    if (authModal) {
        document.getElementById('login-btn')?.addEventListener('click', () => { authModal.style.display = 'flex'; setTimeout(() => authModal.classList.add('show'), 10); });
        document.querySelector('.close-modal')?.addEventListener('click', () => { authModal.classList.remove('show'); setTimeout(() => authModal.style.display = 'none', 300); });
    }

    // Solo cargar carrito si el usuario tiene sesión activa (evita 401 para visitantes)
    if (sessionStorage.getItem('user_logged_in') === 'true') {
        loadCart();
    }

    // Detector de clics para botones dinámicos
    document.addEventListener('click', function (e) {
        const addBtn = e.target.closest('.btn-add-cart');
        if (addBtn) { e.preventDefault(); addToCart(parseInt(addBtn.dataset.id), 1); }

        const viewBtn = e.target.closest('.btn-view-product');
        if (viewBtn) { e.preventDefault(); openProductModal(parseInt(viewBtn.dataset.id)); }
    });

    /* =========================================================
       0. INICIO DE SESIÓN SOCIAL (GOOGLE)
       ========================================================= */

    if (!document.querySelector('script[src="https://accounts.google.com/gsi/client"]')) {
        const script = document.createElement('script');
        script.src = "https://accounts.google.com/gsi/client";
        script.async = true;
        script.defer = true;
        document.head.appendChild(script);
    }

    window.handleGoogleCallback = async function(response) {
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

    function initGoogleAuth() {
        if (window._googleAuthInitialized) return; // Ya inicializado, no repetir
        if (typeof google === 'undefined' || !google.accounts) {
            setTimeout(initGoogleAuth, 100);
            return;
        }
        window._googleAuthInitialized = true;
        google.accounts.id.initialize({
            client_id: '161765677969-t8kq1e2g5ol447aef763p5likq0enqed.apps.googleusercontent.com',
            callback: handleGoogleCallback
        });

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

    initGoogleAuth();

    /* =========================================================
       1. MANEJO DEL LOGIN
       ========================================================= */
    // =========================================================
    // MOBILE MENU LOGIC
    // =========================================================
    const mobileMenuBtn = document.querySelector('.mobile-menu-btn');
    const mainNav = document.querySelector('.main-nav');
    const headerActions = document.querySelector('.header-actions');
    const navLinks = document.querySelectorAll('.nav-link');

    if (mobileMenuBtn && mainNav) {
        mobileMenuBtn.addEventListener('click', () => {
            const isActive = mainNav.classList.toggle('active');
            mobileMenuBtn.innerHTML = isActive ? '<i class="fas fa-times"></i>' : '<i class="fas fa-bars"></i>';
            document.body.style.overflow = isActive ? 'hidden' : '';

            // Toggle header actions visibility if they were moved by CSS
            if (headerActions) {
                headerActions.classList.toggle('active');
            }
        });

        // Close menu when clicking a link
        navLinks.forEach(link => {
            link.addEventListener('click', () => {
                mainNav.classList.remove('active');
                mobileMenuBtn.innerHTML = '<i class="fas fa-bars"></i>';
                document.body.style.overflow = '';
                if (headerActions) headerActions.classList.remove('active');
            });
        });

        // Close menu when clicking outside
        document.addEventListener('click', (e) => {
            if (mainNav.classList.contains('active') &&
                !mainNav.contains(e.target) &&
                !mobileMenuBtn.contains(e.target)) {
                mainNav.classList.remove('active');
                mobileMenuBtn.innerHTML = '<i class="fas fa-bars"></i>';
                document.body.style.overflow = '';
                if (headerActions) headerActions.classList.remove('active');
            }
        });
    }
});
// 8. GESTIÓN DE SESIÓN DE USUARIO (HEADER)
// =========================================================

async function checkSession() {
    try {
        const res = await secureFetch(`${API_BASE_SHOP}/me.php`);
        const data = await res.json();

        if (data.ok && data.user) {
            currentUser = data.user;
            updateHeaderUser(data.user); // Assuming updateHeaderUI is a typo and should be updateHeaderUser

            // Auto-rellenar campos de envío si estamos en checkout
            const addrInput = document.getElementById('shipping-address');
            const cityInput = document.getElementById('shipping-city');
            if (addrInput && !addrInput.value) addrInput.value = data.user.direccion || '';
            if (cityInput && !cityInput.value) cityInput.value = data.user.ciudad || '';

            // Guardar en sessionStorage para acceso rápido
            sessionStorage.setItem('user', JSON.stringify(data.user));
        } else {
            sessionStorage.removeItem('user');
        }
    } catch (error) {
        console.error('Error verificando sesión:', error);
    }
}

function updateHeaderUser(user) {
    const loginBtns = document.querySelectorAll('#login-btn, .mobile-actions .button-secondary, .header-actions-mobile .button-secondary');
    if (!loginBtns.length) return;

    loginBtns.forEach(btn => {
        // Cambiar texto e icono
        btn.innerHTML = `<i class="fas fa-user-circle"></i> ${user.nombre.split(' ')[0]}`;

        // Cambiar comportamiento: Ir al panel en lugar de abrir modal
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

// Asegúrate de llamar a esta función cuando cargue la página
document.addEventListener('DOMContentLoaded', () => {
    // ... tu código existente ...
    loadTestimonials();
    loadServices();
    checkSession(); // <--- NUEVO
});


// Función para cargar reseñas en el home
async function loadTestimonials() {
    const sliderContainer = document.querySelector('.reviews-slider');
    if (!sliderContainer) return;

    try {
        const res = await secureFetch(`${API_BASE}/resenas.php`);
        const data = await res.json();

        if (data.ok && data.resenas.length > 0) {
            // Limpiamos los testimonios estáticos (hardcoded)
            sliderContainer.innerHTML = '';

            data.resenas.forEach(review => {
                const rating = parseFloat(review.calificacion);
                // Generar estrellas HTML (ISO 830: Precisión visual)
                let starsHtml = '';
                for (let i = 1; i <= 5; i++) {
                    if (rating >= i) {
                        starsHtml += '<i class="fas fa-star"></i>'; // Llena
                    } else if (rating >= i - 0.5) {
                        starsHtml += '<i class="fas fa-star-half-alt"></i>'; // Media
                    } else {
                        starsHtml += '<i class="far fa-star"></i>'; // Vacía
                    }
                }

                // Crear tarjeta HTML
                const cardHtml = `
                    <div class="review-card">
                        <div class="review-rating" style="color: var(--warning-color);">
                            ${starsHtml}
                        </div>
                        <p class="review-text">"${review.comentario}"</p>
                        <div class="reviewer-info">
                            <div class="reviewer-avatar" style="background:#333; color:#fff; display:flex; align-items:center; justify-content:center; font-weight:bold;">
                                ${review.nom_usuario.charAt(0).toUpperCase()}
                            </div>
                            <div class="reviewer-details">
                                <p class="reviewer-name">${review.nom_usuario}</p>
                                <p class="reviewer-role">Cliente Verificado</p>
                            </div>
                        </div>
                    </div>
                `;
                sliderContainer.innerHTML += cardHtml;
            });
        }
    } catch (error) {
        console.error('Error cargando testimonios:', error);
    }
}

// Función para cargar servicios dinámicamente
// Función para cargar servicios dinámicamente en CAROUSEL
async function loadServices() {
    const servicesContainer = document.querySelector('#services-section .container'); // Parent container
    const originalGrid = document.getElementById('public-services-grid');

    // Si no existe el contenedor principal o el grid original está fallando, abortamos
    if (!servicesContainer) return;

    try {
        const res = await secureFetch(`${API_BASE_SHOP}/servicios.php`);
        const data = await res.json();

        if (data.ok && data.servicios.length > 0) {
            // 1. Crear estructura del Carrusel
            // Reemplazamos el grid original con la estructura del slider
            if (originalGrid) originalGrid.remove(); // Quitamos el div viejo

            // Verificamos si ya existe el slider para evitar duplicados si se recarga
            let sliderWrapper = document.querySelector('.services-slider-container');
            if (!sliderWrapper) {
                sliderWrapper = document.createElement('div');
                sliderWrapper.className = 'services-slider-container';

                sliderWrapper.innerHTML = `
                    <button class="slider-btn prev"><i class="fas fa-chevron-left"></i></button>
                    <div class="services-slider" id="services-carousel"></div>
                    <button class="slider-btn next"><i class="fas fa-chevron-right"></i></button>
                `;
                servicesContainer.appendChild(sliderWrapper);
            }

            const carouselTrack = document.getElementById('services-carousel');
            carouselTrack.innerHTML = '';

            data.servicios.forEach(s => {
                // Asignar icono basado en palabras clave
                let iconClass = 'fas fa-clock';
                const nameLower = s.nom_servicio.toLowerCase();

                if (nameLower.includes('reparación') || nameLower.includes('reparacion')) iconClass = 'fas fa-tools';
                else if (nameLower.includes('mantenimiento')) iconClass = 'fas fa-cogs';
                else if (nameLower.includes('repuesto') || nameLower.includes('pieza')) iconClass = 'fas fa-box-open';
                else if (nameLower.includes('diagnostico') || nameLower.includes('diagnóstico')) iconClass = 'fas fa-stethoscope';
                else if (nameLower.includes('limpieza')) iconClass = 'fas fa-broom';
                else if (nameLower.includes('batería') || nameLower.includes('pila')) iconClass = 'fas fa-battery-full';
                else if (nameLower.includes('pulsera') || nameLower.includes('correa')) iconClass = 'fas fa-link';

                const card = `
                    <div class="service-card">
                        <div class="card-icon">
                            <i class="${iconClass}"></i>
                        </div>
                        <h3 class="card-title">${s.nom_servicio}</h3>
                        <p class="card-text">${s.descripcion}</p>
                        <ul class="service-features">
                            <li><i class="fas fa-hourglass-half"></i> ${s.duracion_estimada}</li>
                            <li><i class="fas fa-tag"></i> ${formatPrice(s.precio_servicio)}</li>
                        <a href="#contact-section" class="btn btn-outline">
                            Agendar <i class="fas fa-chevron-down"></i>
                        </a>
                    </div>
                `;
                carouselTrack.innerHTML += card;
            });

            // 2. Inicializar lógica del Carrusel
            initServicesCarousel();

        } else {
            if (originalGrid) originalGrid.innerHTML = '<p style="width:100%;text-align:center">No hay servicios disponibles.</p>';
        }
    } catch (error) {
        console.error('Error cargando servicios:', error);
        if (originalGrid) originalGrid.innerHTML = '<p style="width:100%;text-align:center;color:red">Error al cargar servicios.</p>';
    }
}

function initServicesCarousel() {
    const track = document.getElementById('services-carousel');
    const prevBtn = document.querySelector('.services-slider-container .prev');
    const nextBtn = document.querySelector('.services-slider-container .next');

    if (!track || !prevBtn || !nextBtn) return;

    // Helper to get actual card width + gap
    const getCardWidth = () => {
        const card = track.querySelector('.service-card');
        if (!card) return 320; // Fallback
        const style = window.getComputedStyle(track);
        const gap = parseFloat(style.gap) || 20;
        return card.offsetWidth + gap;
    };

    nextBtn.addEventListener('click', () => {
        const cardWidth = getCardWidth();
        const maxScroll = track.scrollWidth - track.clientWidth;

        // Scroll exactly one card width, but don't overshoot max
        let targetScroll = track.scrollLeft + cardWidth;

        // If we are close to the end, snap to end to show last card fully
        if (targetScroll >= maxScroll - 10) { // Tolerance
            targetScroll = maxScroll;
        }

        track.scrollTo({
            top: 0,
            left: targetScroll,
            behavior: 'smooth'
        });
    });

    prevBtn.addEventListener('click', () => {
        const cardWidth = getCardWidth();
        let targetScroll = track.scrollLeft - cardWidth;

        if (targetScroll < 0) targetScroll = 0;

        track.scrollTo({
            top: 0,
            left: targetScroll,
            behavior: 'smooth'
        });
    });

    // Optional: Add resize listener to adjust if needed, though scrollLeft handles it naturally
}

// =========================================================
// LÓGICA DE AUTENTICACIÓN (LOGIN Y REGISTRO)
// =========================================================

document.addEventListener('DOMContentLoaded', () => {

    /* =========================================================
       1. MANEJO DEL LOGIN (TU CÓDIGO ORIGINAL)
       ========================================================= */
    const loginForm = document.getElementById('loginForm');

    if (loginForm) {
        loginForm.addEventListener('submit', async function (e) {
            e.preventDefault(); // <--- ESTO ES VITAL: Evita que la página se recargue

            const emailInput = document.getElementById('login-email');
            const passwordInput = document.getElementById('login-password');
            const btnLogin = loginForm.querySelector('.btn-login');
            const btnText = btnLogin.querySelector('.btn-text');
            const btnLoader = btnLogin.querySelector('.btn-loader');

            // UI Loading
            if (btnText) btnText.style.display = 'none';
            if (btnLoader) btnLoader.style.display = 'inline-block';
            btnLogin.disabled = true;

            // Validaciones Frontend (Nuevo)
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
                // Ajusta esta ruta si tu carpeta backend está en otro lugar
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
                    // Guardar datos básicos en sessionStorage para el frontend
                    sessionStorage.setItem('user', JSON.stringify(data.user));

                    showNotification('✅ Bienvenido ' + data.user.nombre);

                    // Actualizar el header de la landing inmediatamente
                    updateHeaderUser(data.user);

                    // REDIRECCIÓN BASADA EN LA RESPUESTA DEL PHP
                    setTimeout(() => {
                        if (data.redirect) {
                            // Cerrar el modal de auth en la landing
                            const authModal = document.getElementById('auth-modal');
                            if (authModal) {
                                authModal.classList.remove('show');
                                setTimeout(() => authModal.style.display = 'none', 300);
                            }
                            // Abrir el panel en una nueva pestaña
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
                // Restaurar botón
                if (btnText) btnText.style.display = 'inline-block';
                if (btnLoader) btnLoader.style.display = 'none';
                btnLogin.disabled = false;
            }
        });
    }

    /* =========================================================
       1B. MANEJO DE RECUPERACIÓN DE CONTRASEÑA
       ========================================================= */
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
                    // Volver al login después de 3 segundos
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
    
    /* =========================================================
       2. MANEJO DEL REGISTRO (NUEVO CÓDIGO)
       ========================================================= */
    const signupForm = document.getElementById('signupForm');

    if (signupForm) {
        signupForm.addEventListener('submit', async function (e) {
            e.preventDefault();

            // Referencias
            const nameInput = document.getElementById('signup-name');
            const emailInput = document.getElementById('signup-email');
            const phoneInput = document.getElementById('signup-phone');
            const passInput = document.getElementById('signup-password');
            const confirmInput = document.getElementById('signup-password-confirm');

            // === VALIDACIONES FRONTEND ===

            // Validar nombre
            const name = nameInput.value.trim();
            if (!validateName(name)) {
                showNotification('❌ El nombre solo debe contener letras y espacios', true);
                nameInput.focus();
                return;
            }

            // Validar teléfono
            const phone = phoneInput.value.trim();
            if (!validatePhone(phone)) {
                showNotification('❌ El teléfono debe tener 10 dígitos numéricos', true);
                phoneInput.focus();
                return;
            }

            // Validar contraseña
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

            // Validar coincidencia de contraseñas
            if (passInput.value !== confirmInput.value) {
                showNotification('❌ Las contraseñas no coinciden', true);
                confirmInput.focus();
                return;
            }

            // UI Loading
            const btnSignup = signupForm.querySelector('.btn-signup');
            const btnText = btnSignup.querySelector('.btn-text');
            const btnLoader = btnSignup.querySelector('.btn-loader');

            if (btnText) btnText.textContent = ""; // Ocultar texto temporalmente
            if (btnLoader) btnLoader.style.display = 'inline-block';
            btnSignup.disabled = true;

            try {
                // Usamos el archivo que conecta con tu FUN_REGISTRAR_USUARIO
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
                    // Simular clic en "Inicia Sesión" para cambiar la vista
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
                // Restaurar botón
                if (btnText) btnText.textContent = "CREAR CUENTA";
                if (btnLoader) btnLoader.style.display = 'none';
                btnSignup.disabled = false;
            }
        });
    }

    /* =========================================================
       3. FUNCIONALIDADES UI (OJO, TABS, MEDIDOR)
       ========================================================= */

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
            e.preventDefault(); // Evitar submit
            const input = btn.previousElementSibling; // El input está antes del botón
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

    // C. VALIDACIONES Y MEDIDOR DE FUERZA DE CONTRASEÑA

    // === FUNCIONES DE VALIDACIÓN REUTILIZABLES ===

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

    // === VALIDACIÓN EN TIEMPO REAL PARA NOMBRE (SIGNUP) ===
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

    // === VALIDACIÓN EN TIEMPO REAL PARA TELÉFONO (SIGNUP) ===
    const signupPhoneInput = document.getElementById('signup-phone');
    const signupPhoneError = document.getElementById('signup-phone-error');

    if (signupPhoneInput && signupPhoneError) {
        // Bloquear caracteres no numéricos
        signupPhoneInput.addEventListener('keypress', function (e) {
            if (!/^\d$/.test(e.key) && e.key !== 'Backspace' && e.key !== 'Delete' && e.key !== 'Tab' && e.key !== 'ArrowLeft' && e.key !== 'ArrowRight') {
                e.preventDefault();
            }
        });

        signupPhoneInput.addEventListener('input', function () {
            // Eliminar cualquier carácter no numérico
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

    // === MEDIDOR DE FUERZA Y REQUISITOS DE CONTRASEÑA ===
    const passInputSignup = document.getElementById('signup-password');
    const strengthText = document.getElementById('strength-text');
    const bars = document.querySelectorAll('.strength-bar');

    // Elementos de requisitos
    const reqLength = document.getElementById('req-length');
    const reqUppercase = document.getElementById('req-uppercase');
    const reqNumber = document.getElementById('req-number');
    const reqSpecial = document.getElementById('req-special');

    if (passInputSignup && strengthText) {
        passInputSignup.addEventListener('input', function () {
            const val = this.value;
            const requirements = validatePassword(val);

            // Actualizar indicadores visuales de requisitos
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

            // Calcular score para el medidor
            let score = 0;
            if (requirements.length) score++;
            if (requirements.uppercase) score++;
            if (requirements.number) score++;
            if (requirements.special) score++;

            // Actualizar Texto
            const labels = ['Muy Débil', 'Débil', 'Media', 'Fuerte', 'Muy Segura'];
            strengthText.textContent = labels[score] || 'Muy Débil';

            // Colorear Barras
            bars.forEach((bar, idx) => {
                if (idx < score) {
                    if (score <= 1) bar.style.backgroundColor = '#e74c3c'; // Rojo
                    else if (score === 2) bar.style.backgroundColor = '#f1c40f'; // Amarillo
                    else if (score === 3) bar.style.backgroundColor = '#3498db'; // Azul
                    else bar.style.backgroundColor = '#2ecc71'; // Verde
                } else {
                    bar.style.backgroundColor = '#ddd'; // Gris
                }
            });
        });
    }

    // D. ABRIR/CERRAR MODAL
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


// 10. STATS ANIMATION & LOADING (LANDING PAGE)
// =========================================================
async function loadStats() {
    try {
        // Endpoint público — no requiere sesión de admin
        const res = await secureFetch(`${API_BASE}/stats_public.php`);
        const data = await res.json();

        if (data.ok && data.public) {
            // Update the stat numbers with real data from backend
            const statYears = document.getElementById('stat-years');
            const statRepaired = document.getElementById('stat-repaired');
            const statSatisfaction = document.getElementById('stat-satisfaction');

            if (statYears) {
                statYears.setAttribute('data-count', data.public.years);
                animateValue("stat-years", 0, data.public.years, 2000);
            }

            if (statRepaired) {
                statRepaired.setAttribute('data-count', data.public.repaired);
                animateValue("stat-repaired", 0, data.public.repaired, 2000);
            }

            if (statSatisfaction) {
                statSatisfaction.setAttribute('data-count', data.public.satisfaction);
                animateValue("stat-satisfaction", 0, data.public.satisfaction, 2000);
            }
        } else {
            // Fallback: animate with default values already in HTML
            animateValue("stat-years", 0, 50, 2000);
            animateValue("stat-repaired", 0, 12000, 2000);
            animateValue("stat-satisfaction", 0, 98, 2000);
        }
    } catch (error) {
        console.error('Error loading stats:', error);
        // Fallback animation with default values
        animateValue("stat-years", 0, 50, 2000);
        animateValue("stat-repaired", 0, 12000, 2000);
        animateValue("stat-satisfaction", 0, 98, 2000);
    }
}

function animateValue(id, start, end, duration) {
    const obj = document.getElementById(id);
    if (!obj) return;

    let startTimestamp = null;
    const step = (timestamp) => {
        if (!startTimestamp) startTimestamp = timestamp;
        const progress = Math.min((timestamp - startTimestamp) / duration, 1);
        obj.innerHTML = Math.floor(progress * (end - start) + start);
        if (progress < 1) {
            window.requestAnimationFrame(step);
        } else {
            obj.innerHTML = end;
        }
    };
    window.requestAnimationFrame(step);
}

// =========================================================
// 11. CONTACT FORM HANDLER
// =========================================================
async function handleContactForm(e) {
    e.preventDefault();

    const form = e.target;
    const submitBtn = form.querySelector('button[type="submit"]');
    const btnText = submitBtn.querySelector('.btn-text');
    const btnLoader = submitBtn.querySelector('.btn-loader');


    // Get form data
    const nombre = document.getElementById('contact-name').value.trim();
    const email = document.getElementById('contact-email').value.trim();
    const telefono = document.getElementById('contact-phone').value.trim();
    const mensaje = document.getElementById('contact-message').value.trim();

    // === VALIDACIONES ===

    // Validación básica de campos obligatorios
    if (!nombre || !email || !mensaje) {
        showNotification('❌ Por favor completa todos los campos obligatorios', true);
        return;
    }

    // Validar nombre (solo letras y espacios)
    if (!validateName(nombre)) {
        showNotification('❌ El nombre solo debe contener letras y espacios', true);
        document.getElementById('contact-name').focus();
        return;
    }

    // Validar teléfono (si se proporciona)
    if (telefono && !/^\d{10}$/.test(telefono)) {
        showNotification('❌ El teléfono debe tener 10 dígitos numéricos', true);
        document.getElementById('contact-phone').focus();
        return;
    }

    // UI Loading
    if (btnText) btnText.style.display = 'none';
    if (btnLoader) btnLoader.style.display = 'inline-block';
    submitBtn.disabled = true;

    try {
        const payload = {
            nombre,
            email,
            telefono,
            mensaje
        };

        const response = await secureFetch(`${API_BASE}/contacto.php`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        const data = await response.json();

        if (data.ok) {
            showNotification('✅ ' + data.msg);
            form.reset();
        } else {
            showNotification('❌ ' + (data.msg || 'Error al enviar el mensaje'), true);
        }
    } catch (error) {
        console.error('Error en formulario de contacto:', error);
        showNotification('❌ Error de conexión. Por favor intenta nuevamente.', true);
    } finally {
        // Restore button
        if (btnText) btnText.style.display = 'inline-block';
        if (btnLoader) btnLoader.style.display = 'none';
        submitBtn.disabled = false;
    }
}

// =========================================================
// 12. VALIDACIÓN DE TELÉFONO EN CONTACTO
// =========================================================

/**
 * Validación en tiempo real del teléfono de contacto
 */
function setupContactValidation() {
    const phoneInput = document.getElementById('contact-phone');
    if (!phoneInput) return;

    phoneInput.addEventListener('keypress', function (e) {
        if (!/^\d$/.test(e.key) && e.key !== 'Backspace' && e.key !== 'Delete' && e.key !== 'Tab') {
            e.preventDefault();
        }
    });

    phoneInput.addEventListener('input', function () {
        if (this.value.length > 10) {
            this.value = this.value.slice(0, 10);
        }
    });
}

// Inicialización final
document.addEventListener('DOMContentLoaded', () => {
    loadStats();

    // Conectar formulario de contacto
    const contactForm = document.getElementById('contactForm');
    if (contactForm) {
        contactForm.addEventListener('submit', handleContactForm);
    }

    // Configurar validación de contacto
    setupContactValidation();
    
    // Inicializar Google Sign-In si el SDK cargó
    if (typeof google !== 'undefined' && google.accounts) {
        initGoogleSignIn();
    } else {
        // Fallback por si la librería carga un poco más lento
        window.addEventListener('load', () => {
             if (typeof google !== 'undefined' && google.accounts) {
                 initGoogleSignIn();
             }
        });
    }
});

// =========================================================
// 13. GOOGLE OAUTH SIGN-IN
// =========================================================

function initGoogleSignIn() {
    google.accounts.id.initialize({
        client_id: '161765677969-t8kq1e2g5ol447aef763p5likq0enqed.apps.googleusercontent.com',
        callback: handleGoogleCredentialResponse,
        // Evitar que pregunte siempre si ya inició sesión antes (opcional)
        auto_select: false
    });

    // Anclar el comportamiento al botón personalizado de "G" que ya existe en el HTML
    const googleBtn = document.getElementById('googleSignup');
    if (googleBtn) {
        googleBtn.addEventListener('click', (e) => {
            e.preventDefault();
            // Esto renderiza el prompt oficial de Google (no podemos simular clic directamente por seguridad)
            google.accounts.id.prompt(); 
        });
    }
}

async function handleGoogleCredentialResponse(response) {
    // response.credential contiene el JWT token que nos dio Google
    
    // Mostramos feedback visual (opcional)
    showNotification('⏳ Autenticando con Google...', false);
    
    try {
        const res = await secureFetch(`${API_BASE}/auth_google.php`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ credential: response.credential })
        });

        const data = await res.json();

        if (data.ok) {
            showNotification('✅ ' + data.msg);
            // Redirigir al inicio o a donde el rol requiera
            setTimeout(() => {
                 window.location.href = data.data.role === 'admin' ? '/src/admin.html' : 'index.html';
            }, 1000);
        } else {
            showNotification('❌ ' + (data.msg || 'Error en autenticación'), true);
        }
    } catch (error) {
        console.error('Error Google Auth:', error);
        showNotification('❌ Error de conexión al validar con Google.', true);
    }
}

// =========================================================
// AVISO DE COOKIES
// =========================================================
document.addEventListener('DOMContentLoaded', () => {
    const cookieBanner = document.getElementById('cookie-banner');
    const acceptBtn    = document.getElementById('accept-cookies');

    if (cookieBanner && !localStorage.getItem('cookies_accepted')) {
        // Retrasar levemente para que el preloader no compita visualmente
        setTimeout(() => cookieBanner.classList.add('show'), 1500);
    }

    if (acceptBtn) {
        acceptBtn.addEventListener('click', () => {
            localStorage.setItem('cookies_accepted', 'true');
            cookieBanner.classList.remove('show');
        });
    }
});

// =========================================================
// 14. MOBILE MENU (RESPONSIVE)
// =========================================================
document.addEventListener('DOMContentLoaded', () => {
    const mobileBtn = document.querySelector('.mobile-menu-btn');
    const mainNav = document.querySelector('.main-nav');
    
    if (mobileBtn && mainNav) {
        // Clonar las acciones del header si existen
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
                        mainNav.classList.remove('active'); // Cerrar menú al abrir modal
                    }
                });
            }
            
            mainNav.appendChild(mobileActions);
            
            // Si el usuario ya estaba logueado, actualizar el botón clonado
            const userState = sessionStorage.getItem('user');
            if (userState) {
                try {
                    updateHeaderUser(JSON.parse(userState));
                } catch(e) {}
            }
        }

        mobileBtn.addEventListener('click', () => {
            mainNav.classList.toggle('active');
            const icon = mobileBtn.querySelector('i');
            if (mainNav.classList.contains('active')) {
                icon.classList.remove('fa-bars');
                icon.classList.add('fa-times');
            } else {
                icon.classList.remove('fa-times');
                icon.classList.add('fa-bars');
            }
        });

        // Cerrar menú al hacer clic en un enlace
        mainNav.querySelectorAll('.nav-link').forEach(link => {
            link.addEventListener('click', () => {
                mainNav.classList.remove('active');
                const icon = mobileBtn.querySelector('i');
                icon.classList.remove('fa-times');
                icon.classList.add('fa-bars');
            });
        });
    }
});
