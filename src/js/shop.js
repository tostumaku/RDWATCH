/**
 * ARCHIVO: js/shop.js
 * MÓDULO: Catálogo de Productos (Tienda)
 * Dependencias: config.js, security.js, notifications.js, utils.js (formatPrice)
 *
 * Contenido:
 *   - Estado del catálogo (productsData, filteredData)
 *   - Carga de productos desde la API
 *   - Renderizado paginado
 *   - Filtros (categoría, marca, precio, orden)
 *   - Modal de detalle de producto
 */

// =========================================================
// 1. ESTADO DEL CATÁLOGO
// =========================================================
let productsData = [];
let filteredData = [];

const ITEMS_PER_PAGE = 9;
let currentPage = 1;

// Exponer globalmente para que cart.js pueda consultar stock
window._shopProductsData = function () { return productsData; };

// =========================================================
// 2. CARGA DE PRODUCTOS
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
                badge: p.stock === 0 ? 'Agotado' : (p.stock < 5 && p.stock > 0 ? '¡Pocas!' : '')
            }));

            populateBrandFilter(productsData);
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

// =========================================================
// 3. SIDEBAR DE CATEGORÍAS
// =========================================================

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

// =========================================================
// 4. RENDERIZADO PAGINADO
// =========================================================

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
        <div class="product-card" ${p.stock === 0 ? 'style="opacity: 0.8;"' : ''}>
            <div class="product-image-container">
                <img src="${p.img}" alt="${p.name}" class="product-image" ${p.stock === 0 ? 'style="filter: grayscale(80%);"' : ''} onerror="this.src='https://via.placeholder.com/250'">
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

    // Controles de paginación
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

// =========================================================
// 5. FILTROS Y BUSCADORES
// =========================================================

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

    filteredData = productsData.filter(p => {
        const matchCat = activeCategory === 'all' || p.category === activeCategory;
        const matchBrand = brand === 'all' || p.brand === brand;
        const matchPrice = p.price >= minPrice && p.price <= maxPrice;
        return matchCat && matchBrand && matchPrice;
    });

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

// =========================================================
// 6. MODAL DE DETALLE DE PRODUCTO
// =========================================================

function openProductModal(id) {
    const product = productsData.find(p => p.id === id);
    if (!product) return;

    document.getElementById('modal-img').src = product.img;
    document.getElementById('modal-title').textContent = product.name;
    document.getElementById('modal-price').textContent = formatPrice(product.price);
    document.getElementById('modal-desc').textContent = product.description;

    const brandContainer = document.querySelector('#modal-brand span');
    if (brandContainer) brandContainer.textContent = product.brand;

    const stockContainer = document.getElementById('modal-stock');
    if (stockContainer) stockContainer.textContent = 'Stock: ' + product.stock;

    const qtyInput = document.getElementById('modal-qty');
    const addBtn = document.getElementById('modal-add-btn');
    const newBtn = addBtn.cloneNode(true);
    addBtn.parentNode.replaceChild(newBtn, addBtn);

    if (product.stock === 0) {
        qtyInput.value = 0;
        qtyInput.disabled = true;
        newBtn.disabled = true;
        newBtn.innerHTML = '<i class="fas fa-ban"></i> Agotado';
        newBtn.className = 'button button-secondary';
    } else {
        qtyInput.value = 1;
        qtyInput.max = product.stock;
        qtyInput.disabled = false;
        newBtn.disabled = false;
        newBtn.innerHTML = '<i class="fas fa-cart-plus"></i> Agregar al Carrito';
        newBtn.className = 'button button-primary';
        newBtn.onclick = () => {
            addToCart(product.id, parseInt(qtyInput.value));
            document.getElementById('product-detail-modal').style.display = 'none';
        };
    }

    const modal = document.getElementById('product-detail-modal');
    modal.style.display = 'flex';
    setTimeout(() => modal.classList.add('active'), 10);
}

// =========================================================
// 7. INICIALIZACIÓN
// =========================================================

document.addEventListener('DOMContentLoaded', () => {
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

    // Detector de clics para botones dinámicos (delegación de eventos)
    document.addEventListener('click', function (e) {
        const addBtn = e.target.closest('.btn-add-cart');
        if (addBtn) { e.preventDefault(); addToCart(parseInt(addBtn.dataset.id), 1); }

        const viewBtn = e.target.closest('.btn-view-product');
        if (viewBtn) { e.preventDefault(); openProductModal(parseInt(viewBtn.dataset.id)); }
    });
});
