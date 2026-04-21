/**
 * RD WATCH - PANEL DE ADMINISTRACIÓN (CORE UI)
 * ---------------------------------------------------------
 * Propósito: Orquestar la interfaz administrativa de RD-Watch. Gestiona 
 * inventarios, clientes, órdenes y estadísticas en tiempo real.
 * 
 * Pilares de Seguridad:
 * 1. Auth Gate: Valida el rol de 'admin' antes de cargar la interfaz.
 * 2. Secure Fetch: Centraliza las peticiones API con protección CSRF.
 * 3. Atomic Updates: Maneja estados locales para una UI fluida y consistente.
 */
"use strict";

// ==========================================
// 1. VERIFICACIÓN DE AUTENTICACIÓN
// ==========================================
(function checkAuth() {
  // Definimos la base de la API apuntando a la carpeta EXACTA
  const API_BASE = API_CONFIG.baseUrl;

  // Verificar si hay sesión activa
  secureFetch(`${API_BASE}/me.php`, {
    method: 'GET'
  })
    .then(res => res.json())
    .then(data => {
      // Si no hay sesión, redirigir al login usando replace() para eliminar del historial
      if (!data.ok || !data.user) {
        sessionStorage.removeItem('user');
        showNotification('⚠️ Debes iniciar sesión para acceder al panel de administración');
        const appUrl = API_CONFIG.appUrl || '../..';
        window.location.replace(`${appUrl}/index.html`);
        return;
      }

      // Verificación de rol
      if (data.user.rol !== 'admin') {
        sessionStorage.removeItem('user');
        showNotification('⚠️ No tienes permisos de administrador');
        const appUrl = API_CONFIG.appUrl || '../..';
        window.location.replace(`${appUrl}/index.html`);
        return;
      }

      // Usuario admin autenticado correctamente
    })
    .catch(err => {
      console.error('Error verificando sesión:', err);
      // En caso de error, sacar al usuario a la ruta correcta
      sessionStorage.removeItem('user');
      const appUrl = API_CONFIG.appUrl || '../..';
      window.location.replace(`${appUrl}/index.html`);
    });
})();

// ==========================================
// 2. FUNCIÓN DE LOGOUT (CORREGIDO)
// ==========================================
async function cerrarSesion() {
  const ok = await showConfirm('¿Deseas cerrar sesión?', {
      confirmText: 'Cerrar sesión',
      cancelText: 'Cancelar'
  });
  if (!ok) return;

  const API_BASE = API_CONFIG.baseUrl;

  secureFetch(`${API_BASE}/logout.php`, {
    method: 'POST'
  })
    .then(res => res.json())
    .then(data => {
      sessionStorage.removeItem('user');
      sessionStorage.removeItem('csrf_token');
      // 🛡️ replace() elimina esta página del historial del navegador,
      // impidiendo que el admin vuelva al panel con la flecha "atrás".
      const appUrl = API_CONFIG.appUrl || '../..';
      window.location.replace(`${appUrl}/index.html`);
    })
    .catch(err => {
      console.error('Error al cerrar sesión:', err);
      sessionStorage.clear();
      const appUrl = API_CONFIG.appUrl || '../..';
      window.location.replace(`${appUrl}/index.html`);
    });
}

// ==========================================
// 3. LÓGICA DEL DASHBOARD (CRUD)
// ==========================================
document.addEventListener("DOMContentLoaded", () => {
  const API_BASE = API_CONFIG.baseUrl;

  // Estado local
  let productos = [];
  let pedidos = [];
  let clientes = [];
  let servicios = [];
  let marcas = [];
  let categorias = [];
  let subcategorias = [];
  let citas = []; // NUEVO


  /* ===== Navegación ===== */
  const links = document.querySelectorAll(".admin-link");
  const sections = document.querySelectorAll(".admin-section");
  if (links.length && sections.length) {
    links.forEach((btn) => {
      btn.addEventListener("click", () => {
        links.forEach((b) => b.classList.remove("active"));
        btn.classList.add("active");
        const target = btn.dataset.target || "";

        sections.forEach((sec) => {
          if (sec.id === target) {
            sec.classList.add("is-active");
            // Recargar datos específicos si es necesario
            if (target === 'citas') renderCitas();
          } else {
            sec.classList.remove("is-active");
          }
        });
      });
    });
  }

  /* ===== Sidebar móvil ===== */
  const sidebar = document.getElementById("adminSidebar");
  const openMenuBtn = document.getElementById("btn-open-admin-menu");
  if (sidebar && openMenuBtn) {
    openMenuBtn.addEventListener("click", () => {
      sidebar.classList.toggle("open");
    });
  }

  /* ===== Modal utils ===== */
  const modalOverlay = document.getElementById("modalOverlay");
  function openModal(id) {
    const el = document.querySelector(id);
    if (!el || !modalOverlay) return;
    el.style.display = "flex";
    requestAnimationFrame(() => el.classList.add("show"));
    modalOverlay.classList.add("show");
  }

  /**
   * Muestra un modal de alerta profesional (Reemplaza alert estándar)
   */
  async function showAlert(msg, title = "Atención") {
    const elTitle = document.getElementById("tituloAlerta");
    const elMsg = document.getElementById("mensajeAlerta");
    if (elTitle) elTitle.innerHTML = `<i class="fas fa-exclamation-triangle"></i> ${title}`;
    if (elMsg) elMsg.textContent = msg;
    openModal("#modalAlerta");
  }
  function closeModal(id) {
    const el = document.querySelector(id);
    if (!el || !modalOverlay) return;
    el.classList.remove("show");
    setTimeout(() => { el.style.display = "none"; }, 200);
    modalOverlay.classList.remove("show");
  }
  document.querySelectorAll("[data-close]").forEach((btn) => {
    btn.addEventListener("click", () => closeModal(btn.dataset.close));
  });
  if (modalOverlay) {
    modalOverlay.addEventListener("click", () => {
      document.querySelectorAll(".modal").forEach((m) => {
        if (getComputedStyle(m).display !== "none") closeModal("#" + m.id);
      });
    });
  }

  /* ===== Dashboard ===== */
  async function cargarEstadisticas() {
    try {
      const res = await secureFetch(`${API_BASE}/stats.php`);
      const data = await res.json();
      if (data.ok) {
        const { productos, pedidos, clientes, servicios, ventas_monto, ventas_cant } = data.stats;
        const sp = document.getElementById("statProductos");
        const spe = document.getElementById("statPedidos");
        const sc = document.getElementById("statClientes");
        const ss = document.getElementById("statServicios");
        const svm = document.getElementById("statVentasMonto");
        const svc = document.getElementById("statVentasCant");

        if (sp) sp.textContent = String(productos);
        if (spe) spe.textContent = String(pedidos);
        if (sc) sc.textContent = String(clientes);
        if (ss) ss.textContent = String(servicios);
        if (svc) svc.textContent = String(ventas_cant);
        if (svm) svm.textContent = typeof formatPrice === 'function' ? formatPrice(ventas_monto) : '$' + ventas_monto.toLocaleString();
      }
    } catch (error) {
      console.error("Error cargando estadísticas:", error);
    }
  }

  function renderDashboard() {
    cargarEstadisticas();

    const ctx = document.getElementById("estadosChart");
    if (ctx && typeof Chart !== "undefined") {
      const estados = ["pendiente", "confirmado", "enviado", "cancelado"];
      const mapping = {
        "pendiente": { label: "Pendientes", color: "#FFD700" }, // Oro brillante
        "confirmado": { label: "Confirmados", color: "#AF944F" }, // Oro marca
        "enviado": { label: "Enviados", color: "#2E7D32" }, // Verde esmeralda oscuro
        "cancelado": { label: "Cancelados", color: "#92000A" } // Rojo carmesí marca
      };

      const labels = estados.map(e => mapping[e].label);
      const counts = estados.map(e => pedidos.filter(p => p.estado === e).length);
      const colors = estados.map(e => mapping[e].color);

      if (ctx._chartInstance) ctx._chartInstance.destroy();
      ctx._chartInstance = new Chart(ctx, {
        type: "bar",
        data: {
          labels: labels,
          datasets: [{
            label: "Cantidad de Pedidos",
            data: counts,
            backgroundColor: colors,
            borderRadius: 6,
            borderWidth: 0
          }]
        },
        options: {
          responsive: true,
          maintainAspectRatio: false,
          plugins: {
            legend: { display: false }
          },
          scales: {
            y: {
              beginAtZero: true,
              grid: { color: 'rgba(0,0,0,0.05)' },
              ticks: { font: { family: 'Montserrat' } }
            },
            x: {
              grid: { display: false },
              ticks: { font: { family: 'Montserrat', weight: '600' } }
            }
          }
        }
      });
    }
  }

  /* =======================
   * PRODUCTOS
   * ======================= */
  const tbodyProductos = document.getElementById("tbodyProductos");
  const buscarProducto = document.getElementById("buscarProducto");
  const btnNuevoProducto = document.getElementById("btnNuevoProducto");

  async function cargarProductos() {
    try {
      const res = await secureFetch(`${API_BASE}/productos.php`);
      const data = await res.json();
      if (data.ok) {
        productos = data.productos.map(p => ({
          id: p.id_producto,
          nombre: p.nom_producto,
          precio: parseFloat(p.precio),
          stock: parseInt(p.stock),
          estado: p.estado !== false && p.estado !== 'false',
          imagen: p.url_imagen || 'https://via.placeholder.com/90x90?text=Producto',
          marca: p.nom_marca || 'N/A',
          categoria: p.nom_categoria || 'N/A',
          descripcion: p.descripcion || '',
          id_marca: p.id_marca,
          id_categoria: p.id_categoria,
          id_subcategoria: p.id_subcategoria
        }));
        drawProductos();
      }
    } catch (err) {
      console.error('Error cargando productos:', err);
      // showNotification('Error al cargar productos'); // Comentado para no spammear alertas si falla la primera carga
    }
  }

  function drawProductos(list = productos) {
    if (!tbodyProductos) return;
    tbodyProductos.innerHTML = list.map((p) => `
      <tr class="${!p.estado ? 'row-inactive' : ''}">
        <td><img src="${p.imagen}" alt="${p.nombre}"></td>
        <td>${p.nombre}</td>
        <td>$${Number(p.precio).toFixed(2)}</td>
        <td>${p.stock}</td>
        <td>${p.marca}</td>
        <td><span class="badge ${p.estado ? 'active' : 'inactive'}">${p.estado ? 'Activo' : 'Inactivo'}</span></td>
        <td class="actions">
          <button class="button button-outline" onclick="editarProducto(${p.id})"><i class="fas fa-pen"></i></button>
          ${p.estado
            ? `<button class="button button-danger" onclick="desactivarProducto(${p.id})" title="Desactivar"><i class="fas fa-ban"></i></button>`
            : `<button class="button button-success" onclick="reactivarProducto(${p.id})" title="Reactivar"><i class="fas fa-undo"></i></button>`
          }
        </td>
      </tr>`).join("");
  }

  if (buscarProducto) {
    buscarProducto.addEventListener("input", (e) => {
      const q = String(e.target.value || "").toLowerCase();
      drawProductos(productos.filter((p) => p.nombre.toLowerCase().includes(q)));
    });
  }

  const modalProducto = document.getElementById("modalProducto");
  const formProducto = document.getElementById("formProducto");
  const pId = document.getElementById("pId");
  const pNombre = document.getElementById("pNombre");
  const pDescripcion = document.getElementById("pDescripcion");
  const pPrecio = document.getElementById("pPrecio");
  const pStock = document.getElementById("pStock");
  const pImagen = document.getElementById("pImagen");
  const pMarca = document.getElementById("pMarca");
  const pCategoria = document.getElementById("pCategoria");
  const pSubcategoria = document.getElementById("pSubcategoria");

  async function cargarCatalogosProducto() {
    try {
      const [resMarcas, resCat] = await Promise.all([
        secureFetch(`${API_BASE}/catalogos.php?tipo=marcas`),
        secureFetch(`${API_BASE}/catalogos.php?tipo=categorias`)
      ]);
      const [dataMarcas, dataCat] = [await resMarcas.json(), await resCat.json()];
      if (dataMarcas.ok) {
        pMarca.innerHTML = '<option value="">Seleccione...</option>' +
          dataMarcas.marcas.map(m => `<option value="${m.id_marca}">${m.nom_marca}</option>`).join('');
      }
      if (dataCat.ok) {
        pCategoria.innerHTML = '<option value="">Seleccione...</option>' +
          dataCat.categorias.map(c => `<option value="${c.id_categoria}">${c.nom_categoria}</option>`).join('');
      }
    } catch (err) {
      console.error('Error cargando catálogos (producto):', err);
    }
  }

  if (pCategoria) {
    pCategoria.addEventListener('change', async () => {
      const idCat = pCategoria.value;
      if (!idCat) {
        pSubcategoria.innerHTML = '<option value="">Seleccione...</option>';
        return;
      }
      try {
        const res = await secureFetch(`${API_BASE}/catalogos.php?tipo=subcategorias&id_categoria=${idCat}`);
        const data = await res.json();
        if (data.ok) {
          pSubcategoria.innerHTML = '<option value="">Seleccione...</option>' +
            data.subcategorias.map(s => `<option value="${s.id_subcategoria}">${s.nom_subcategoria}</option>`).join('');
        }
      } catch (err) {
        console.error('Error cargando subcategorías:', err);
      }
    });
  }

  if (btnNuevoProducto && formProducto) {
    btnNuevoProducto.addEventListener("click", async () => {
      const title = document.getElementById("tituloModalProducto");
      if (title) title.textContent = "Nuevo Producto";
      formProducto.reset();
      formProducto.dataset.editing = "";
      await cargarCatalogosProducto();
      const maxId = productos.length > 0 ? Math.max(...productos.map(p => p.id)) : 0;
      pId.value = maxId + 1;
      openModal("#modalProducto");
    });
  }

  function editarProducto(id) {
    if (!formProducto) return;
    const prod = productos.find((p) => p.id === id);
    if (!prod) return;
    cargarCatalogosProducto().then(() => {
      const title = document.getElementById("tituloModalProducto");
      if (title) title.textContent = "Editar Producto";
      pId.value = prod.id; pId.readOnly = true;
      pNombre.value = prod.nombre;
      pDescripcion.value = prod.descripcion || '';
      pPrecio.value = prod.precio;
      pStock.value = prod.stock || 0;
      pImagen.value = prod.imagen;
      setTimeout(() => {
        if (prod.id_marca) pMarca.value = prod.id_marca;
        if (prod.id_categoria) {
          pCategoria.value = prod.id_categoria;
          pCategoria.dispatchEvent(new Event('change'));
          setTimeout(() => { if (prod.id_subcategoria) pSubcategoria.value = prod.id_subcategoria; }, 500);
        }
      }, 300);
      formProducto.dataset.editing = String(id);
      openModal("#modalProducto");
    });
  }

  async function desactivarProducto(id) {
    if (!await showConfirm('¿Desactivar este producto? Quedará oculto del catálogo pero podrás reactivarlo desde aquí.', { danger: true, confirmText: 'Desactivar', cancelText: 'Cancelar' })) return;
    try {
      const res = await secureFetch(`${API_BASE}/productos.php`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id_producto: id })
      });
      const data = await res.json();
      if (data.ok) {
        showNotification('Producto desactivado. Puedes reactivarlo desde el panel.');
        await cargarProductos();
        renderDashboard();
      } else {
        showAlert(data.msg || 'Error al desactivar producto', 'Bloqueo de Seguridad');
      }
    } catch (err) {
      console.error(err);
      showAlert('Error técnico al intentar desactivar: ' + err.message, 'Fallo Crítico');
    }
  }

  async function reactivarProducto(id) {
    const prod = productos.find(p => p.id === id);
    if (!prod) return;
    if (!await showConfirm('¿Reactivar este producto? Volverá a ser visible en el catálogo.', { confirmText: 'Reactivar', cancelText: 'Cancelar' })) return;
    try {
      const res = await secureFetch(`${API_BASE}/productos.php`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id_producto: prod.id,
          nom_producto: prod.nombre,
          descripcion: prod.descripcion,
          precio: prod.precio,
          stock: prod.stock,
          url_imagen: prod.imagen,
          id_marca: prod.id_marca,
          id_categoria: prod.id_categoria,
          id_subcategoria: prod.id_subcategoria,
          estado: true
        })
      });
      const data = await res.json();
      if (data.ok) {
        showNotification('✅ Producto reactivado correctamente.');
        await cargarProductos();
        renderDashboard();
      } else {
        showAlert(data.msg || 'Error al reactivar producto', 'Error');
      }
    } catch (err) {
      console.error(err);
      showAlert('Error técnico al reactivar: ' + err.message, 'Fallo Crítico');
    }
  }

  if (formProducto) {
    formProducto.addEventListener("submit", async (e) => {
      e.preventDefault();
      const payload = {
        id_producto: Number(pId.value),
        id_marca: Number(pMarca.value),
        nom_producto: pNombre.value.trim(),
        descripcion: pDescripcion.value.trim(),
        precio: Number(pPrecio.value),
        id_categoria: Number(pCategoria.value),
        id_subcategoria: Number(pSubcategoria.value),
        stock: Number(pStock.value),
        url_imagen: pImagen.value.trim() || null
      };
      const editing = formProducto.dataset.editing;
      try {
        const method = editing ? 'PUT' : 'POST';
        const res = await secureFetch(`${API_BASE}/productos.php`, {
          method, headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        const data = await res.json();
        if (data.ok) {
          showNotification(data.msg || 'Guardado');
          closeModal("#modalProducto");
          pId.readOnly = false;
          await cargarProductos();
          renderDashboard();
        } else {
          showNotification(data.msg || 'Error al guardar producto');
        }
      } catch (err) {
        console.error(err);
        showNotification('Error guardando producto: ' + err.message);
      }
    });
  }

  window.editarProducto = editarProducto;
  window.desactivarProducto = desactivarProducto;
  window.reactivarProducto = reactivarProducto;

  /* =======================
   * PEDIDOS & CLIENTES
   * ======================= */
  const tbodyPedidos = document.getElementById("tbodyPedidos");
  const tbodyClientes = document.getElementById("tbodyClientes");

  async function cargarPedidos() {
    try {
      const res = await secureFetch(`${API_BASE}/pedidos.php`, {
        method: 'GET'
      });
      const data = await res.json();

      if (data.ok) {
        pedidos = data.pedidos.map(p => ({
          id: p.id_orden,
          cliente: p.cliente, // Viene del JOIN con tab_Usuarios
          email: p.email_cliente,
          estado: p.estado_orden,
          total: parseFloat(p.total_orden),
          fecha: p.fecha,
          tiene_comprobante: p.tiene_comprobante == 1
        }));

        drawPedidos();
        renderDashboard();
      }
    } catch (err) {
      console.error('Error cargando pedidos:', err);
    }
  }

  function drawPedidos(list = pedidos) {
    const tbodyPedidos = document.getElementById("tbodyPedidos");
    if (!tbodyPedidos) return;

    // Aplicar filtros manuales si los inputs existen
    const statusFilter = document.getElementById("filtroEstadoPedido")?.value || "";
    const searchFilter = document.getElementById("buscarPedido")?.value.toLowerCase() || "";

    const filtered = list.filter(p => {
      const matchStatus = !statusFilter || p.estado.toLowerCase() === statusFilter.toLowerCase();
      const matchSearch = !searchFilter ||
        p.cliente.toLowerCase().includes(searchFilter) ||
        p.id.toString().includes(searchFilter);
      return matchStatus && matchSearch;
    });

    if (filtered.length === 0) {
      tbodyPedidos.innerHTML = '<tr><td colspan="6" style="text-align:center">No se encontraron pedidos con estos filtros</td></tr>';
      return;
    }

    tbodyPedidos.innerHTML = filtered
      .map((p) => `
        <tr>
          <td>#${p.id}</td>
          <td>
            <strong>${p.cliente}</strong><br>
            <small style="color:#555">${p.email}</small>
          </td>
          <td>${p.fecha}</td>
          <td>
            <select class="form-control select-estado" onchange="cambiarEstadoPedido(${p.id}, this.value)" 
              style="padding: 5px; border-radius: 4px; border: 1px solid #ddd; font-weight: bold;
              background: ${p.estado === 'cancelado' ? '#dc3545' : p.estado === 'confirmado' ? '#007bff' : p.estado === 'enviado' ? '#28a745' : '#ffc107'};
              color: ${p.estado === 'pendiente' ? '#000' : '#fff'};">
              <option value="pendiente" ${p.estado === 'pendiente' ? 'selected' : ''}>Pendiente</option>
              <option value="confirmado" ${p.estado === 'confirmado' ? 'selected' : ''}>Confirmado</option>
              <option value="enviado" ${p.estado === 'enviado' ? 'selected' : ''}>Enviado</option>
              <option value="cancelado" ${p.estado === 'cancelado' ? 'selected' : ''}>Cancelado</option>
            </select>
          </td>
          <td style="text-align:center;">
             ${p.tiene_comprobante
          ? `<a href="../backend/api/get_comprobante.php?id_orden=${p.id}" target="_blank" class="button button-small button-outline" title="Ver Comprobante"><i class="fas fa-file-invoice-dollar"></i></a>`
          : '<span style="color:#ccc;font-size:0.8em;">-</span>'}
          </td>
          <td style="font-weight:bold">$${p.total.toFixed(2)}</td>
        </tr>`)
      .join("");
  }

  // Listeners para Pedidos
  document.getElementById("buscarPedido")?.addEventListener("input", () => drawPedidos());
  document.getElementById("filtroEstadoPedido")?.addEventListener("change", () => drawPedidos());

  window.cambiarEstadoPedido = async function (id_orden, nuevo_estado) {
    if (!await showConfirm(`¿Deseas cambiar el estado a ${nuevo_estado}?`, { confirmText: 'Cambiar estado', cancelText: 'Cancelar' })) return;

    try {
      const res = await secureFetch(`${API_BASE}/pedidos.php`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id_orden, estado: nuevo_estado })
      });

      const data = await res.json();
      if (data.ok) {
        showNotification(`✅ Pedido #${id_orden} actualizado a ${nuevo_estado}`);
        cargarPedidos();
      } else {
        showNotification(`❌ Error: ${data.msg}`);
      }
    } catch (err) {
      console.error('Error al cambiar estado:', err);
      showNotification('❌ Error de conexión');
    }
  };

  /* ==========================
   * FUNCIÓN CARGAR CLIENTES 
   * ========================== */
  async function cargarClientes() {
    try {
      const res = await secureFetch(`${API_BASE}/clientes.php`, {
        method: 'GET'
      });
      const data = await res.json();

      if (data.ok) {
        // Mapeamos los datos de la BD a la estructura que usa la tabla
        clientes = data.clientes.map(c => ({
          id: c.id_usuario,
          nombre: c.nom_usuario,
          email: c.correo_usuario,
          tel: c.num_telefono_usuario || 'N/A',
          activo: c.activo,
          fecha: c.fecha_registro
        }));

        drawClientes();
        renderDashboard(); // Para actualizar el contador del dashboard
      }
    } catch (err) {
      console.error('Error cargando clientes:', err);
    }
  }

  function drawClientes(list = clientes) {
    const tbodyClientes = document.getElementById("tbodyClientes");
    if (!tbodyClientes) return;

    const searchFilter = document.getElementById("buscarCliente")?.value.toLowerCase() || "";
    const statusFilter = document.getElementById("filtroEstadoCliente")?.value || "";

    const filtered = list.filter(c => {
      const matchSearch = !searchFilter ||
        c.nombre.toLowerCase().includes(searchFilter) ||
        c.email.toLowerCase().includes(searchFilter);
      // activo viene como booleano de PostgreSQL (true/false).
      // El select envía "1" (activo) o "0" (inactivo).
      // Convertimos activo a número para que coincidan: true→1, false→0
      const matchStatus = !statusFilter || Number(c.activo).toString() === statusFilter;
      return matchSearch && matchStatus;
    });

    if (filtered.length === 0) {
      tbodyClientes.innerHTML = '<tr><td colspan="4" style="text-align:center">No se encontraron clientes con estos filtros</td></tr>';
      return;
    }

    tbodyClientes.innerHTML = filtered
      .map((c) => `
        <tr>
          <td>
            <strong>${c.nombre}</strong><br>
            <small style="color:#555">ID: ${c.id}</small>
          </td>
          <td>${c.email}</td>
          <td>${c.tel}</td>
          <td>
            <span class="badge ${c.activo ? 'active' : 'inactive'}" style="background: ${c.activo ? '#28a745' : '#6c757d'}; color: #fff; padding: 4px 8px; border-radius: 4px; font-size: 0.8em; font-weight: bold;">
                ${c.activo ? 'ACTIVO' : 'INACTIVO'}
            </span>
          </td>
          <td>
            <button class="button ${c.activo ? 'button-danger' : 'button-primary'}" 
                    style="padding: 4px 8px; font-size: 0.8em;"
                    onclick="cambiarEstadoCliente(${c.id}, ${c.activo})">
              <i class="fas ${c.activo ? 'fa-user-slash' : 'fa-user-check'}"></i> 
              ${c.activo ? 'Desactivar' : 'Activar'}
            </button>
          </td>
        </tr>`)
      .join("");
  }

  // Listeners para Clientes
  document.getElementById("buscarCliente")?.addEventListener("input", () => drawClientes());
  document.getElementById("filtroEstadoCliente")?.addEventListener("change", () => drawClientes());

  /**
   * Cambia el estado (Activo/Inactivo) de un cliente.
   */
  async function cambiarEstadoCliente(id, estadoActual) {
    const nuevoEstado = !estadoActual;
    const accionText = nuevoEstado ? 'ACTIVAR' : 'DESACTIVAR';

    if (!await showConfirm(`¿Desea ${accionText} la cuenta de este cliente?`, { confirmText: 'Confirmar', cancelText: 'Cancelar', danger: accionText === 'desactivar' })) return;

    try {
      const res = await secureFetch(`${API_BASE}/clientes.php`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id_usuario: id,
          activo: nuevoEstado
        })
      });

      const data = await res.json();
      if (data.ok) {
        showNotification(`✅ Cliente ${nuevoEstado ? 'activado' : 'desactivado'} con éxito`);
        await cargarClientes(); // Recargar lista y redibujar
      } else {
        showAlert(data.msg || 'No se pudo cambiar el estado del cliente', 'Gestión de Clientes');
      }
    } catch (err) {
      console.error('Error al cambiar estado de cliente:', err);
      showNotification('❌ Error técnico al intentar procesar el cambio');
    }
  }

  // Exponer a global para el onclick dinámico
  window.cambiarEstadoCliente = cambiarEstadoCliente;
  /* =======================
   * SERVICIOS
   * ======================= */
  const tbodyServicios = document.getElementById("tbodyServicios");
  const btnNuevoServicio = document.getElementById("btnNuevoServicio");
  const formServicio = document.getElementById("formServicio");
  const sId = document.getElementById("sId");
  const sNombre = document.getElementById("sNombre");
  const sDescripcion = document.getElementById("sDescripcion");
  const sPrecio = document.getElementById("sPrecio");
  const sDuracion = document.getElementById("sDuracion");
  const buscarServicio = document.getElementById("buscarServicio");

  async function cargarServicios() {
    try {
      const res = await secureFetch(`${API_BASE}/servicios.php`);
      const data = await res.json();
      if (data.ok) {
        servicios = data.servicios;
        drawServicios();
      }
    } catch (err) {
      console.error('Error cargando servicios:', err);
      // showNotification('Error al cargar servicios');
    }
  }

  function drawServicios(list = servicios) {
    if (!tbodyServicios) return;
    tbodyServicios.innerHTML = list.map((s) => `
      <tr class="${!s.estado ? 'row-inactive' : ''}">
        <td>${s.id_servicio}</td>
        <td>${s.nom_servicio}</td>
        <td>$${Number(s.precio_servicio).toFixed(2)}</td>
        <td>${s.duracion_estimada} min</td>
        <td><span class="badge ${s.estado ? 'active' : 'inactive'}">${s.estado ? 'Activo' : 'Inactivo'}</span></td>
        <td class="actions">
          <button class="button button-outline" onclick="editarServicio(${s.id_servicio})"><i class="fas fa-pen"></i></button>
          ${s.estado
            ? `<button class="button button-danger" onclick="desactivarServicio(${s.id_servicio})" title="Desactivar"><i class="fas fa-ban"></i></button>`
            : `<button class="button button-success" onclick="reactivarServicio(${s.id_servicio})" title="Reactivar"><i class="fas fa-undo"></i></button>`
          }
        </td>
      </tr>`).join("");
  }

  if (buscarServicio) {
    buscarServicio.addEventListener("input", (e) => {
      const q = String(e.target.value || "").toLowerCase();
      drawServicios(servicios.filter((s) => s.nom_servicio.toLowerCase().includes(q)));
    });
  }

  if (btnNuevoServicio && formServicio) {
    btnNuevoServicio.addEventListener("click", () => {
      const title = document.getElementById("tituloModalServicio");
      if (title) title.textContent = "Nuevo Servicio";
      formServicio.reset();
      formServicio.dataset.editing = "";
      const maxId = servicios.length > 0 ? Math.max(...servicios.map(s => s.id_servicio)) : 100;
      sId.value = maxId + 1;
      openModal("#modalServicio");
    });
  }

  function editarServicio(id) {
    if (!formServicio) return;
    const s = servicios.find((x) => x.id_servicio === id);
    if (!s) return;
    const title = document.getElementById("tituloModalServicio");
    if (title) title.textContent = "Editar Servicio";
    sId.value = String(s.id_servicio); sId.readOnly = true;
    sNombre.value = s.nom_servicio;
    sDescripcion.value = s.descripcion;
    sPrecio.value = String(s.precio_servicio);
    sDuracion.value = String(s.duracion_estimada);
    formServicio.dataset.editing = String(id);
    openModal("#modalServicio");
  }

  if (formServicio) {
    formServicio.addEventListener("submit", async (e) => {
      e.preventDefault();
      const payload = {
        id_servicio: Number(sId.value),
        nom_servicio: sNombre.value.trim(),
        descripcion: sDescripcion.value.trim(),
        precio_servicio: Number(sPrecio.value),
        duracion_estimada: Number(sDuracion.value)
      };
      const editing = formServicio.dataset.editing;
      try {
        const method = editing ? 'PUT' : 'POST';
        const res = await secureFetch(`${API_BASE}/servicios.php`, {
          method, headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        const data = await res.json();
        if (data.ok) {
          showNotification(data.msg || 'Guardado');
          closeModal("#modalServicio");
          sId.readOnly = false;
          await cargarServicios();
          renderDashboard();
        } else {
          showNotification(data.msg || 'Error al guardar servicio');
        }
      } catch (err) {
        console.error(err);
        showNotification("Error guardando el servicio: " + err.message);
      }
    });
  }

  async function desactivarServicio(id) {
    if (!await showConfirm('¿Desactivar este servicio? Quedará oculto pero podrás reactivarlo.', { danger: true, confirmText: 'Desactivar', cancelText: 'Cancelar' })) return;
    try {
      const res = await secureFetch(`${API_BASE}/servicios.php`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id_servicio: id })
      });
      const data = await res.json();
      if (data.ok) {
        showNotification('Servicio desactivado. Puedes reactivarlo desde el panel.');
        await cargarServicios();
        renderDashboard();
      } else {
        showAlert(data.msg || 'Este servicio no puede ser desactivado actualmente.', 'Bloqueo de Seguridad');
      }
    } catch (err) {
      console.error(err);
      showNotification("Error desactivando servicio: " + err.message);
    }
  }

  async function reactivarServicio(id) {
    const srv = servicios.find(x => x.id_servicio === id);
    if (!srv) return;
    if (!await showConfirm('¿Reactivar este servicio? Volverá a estar disponible.', { confirmText: 'Reactivar', cancelText: 'Cancelar' })) return;
    try {
      const res = await secureFetch(`${API_BASE}/servicios.php`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id_servicio: srv.id_servicio,
          nom_servicio: srv.nom_servicio,
          descripcion: srv.descripcion,
          precio_servicio: srv.precio_servicio,
          duracion_estimada: srv.duracion_estimada,
          estado: true
        })
      });
      const data = await res.json();
      if (data.ok) {
        showNotification('✅ Servicio reactivado correctamente.');
        await cargarServicios();
        renderDashboard();
      } else {
        showAlert(data.msg || 'Error al reactivar servicio', 'Error');
      }
    } catch (err) {
      console.error(err);
      showAlert('Error técnico al reactivar: ' + err.message, 'Fallo Crítico');
    }
  }

  window.editarServicio = editarServicio;
  window.desactivarServicio = desactivarServicio;
  window.reactivarServicio = reactivarServicio;

  /* =======================
   * MARCAS
   * ======================= */
  const tbodyMarcas = document.getElementById("tbodyMarcas");
  const btnNuevaMarca = document.getElementById("btnNuevaMarca");
  const formMarca = document.getElementById("formMarca");
  const mId = document.getElementById("mId");
  const mNombre = document.getElementById("mNombre");
  const mActiva = document.getElementById("mActiva");
  const buscarMarca = document.getElementById("buscarMarca");

  async function cargarMarcas() {
    try {
      // Usar el endpoint de administración (marcas.php) para obtener TODAS las marcas (incluidas inactivas)
      const res = await secureFetch(`${API_BASE}/marcas.php`);
      const data = await res.json();
      if (data.ok) {
        // El endpoint devuelve: id_marca, nom_marca, estado_marca
        marcas = data.marcas.map(x => ({
          id_marca: x.id_marca,
          nom_marca: x.nom_marca,
          estado_marca: x.estado_marca // Booleano o entero, se usará para el badge
        }));
        drawMarcas();
      }
    } catch (e) {
      console.error('Error cargando marcas:', e);
    }
  }

  function drawMarcas(list = marcas) {
    if (!tbodyMarcas) return;
    tbodyMarcas.innerHTML = list.map(m => `
      <tr class="${!m.estado_marca ? 'row-inactive' : ''}">
        <td>${m.id_marca}</td>
        <td>${m.nom_marca}</td>
        <td><span class="badge ${m.estado_marca ? 'active' : 'inactive'}">${m.estado_marca ? 'Activa' : 'Inactiva'}</span></td>
        <td class="actions">
          <button class="button button-outline" onclick="editarMarca(${m.id_marca})"><i class="fas fa-pen"></i></button>
          ${m.estado_marca
            ? `<button class="button button-danger" onclick="desactivarMarca(${m.id_marca})" title="Desactivar"><i class="fas fa-ban"></i></button>`
            : `<button class="button button-success" onclick="reactivarMarca(${m.id_marca})" title="Reactivar"><i class="fas fa-undo"></i></button>`
          }
        </td>
      </tr>`).join('');
  }

  if (buscarMarca) {
    buscarMarca.addEventListener('input', (e) => {
      const q = e.target.value.toLowerCase();
      drawMarcas(marcas.filter(m => m.nom_marca.toLowerCase().includes(q)));
    });
  }

  if (btnNuevaMarca && formMarca) {
    btnNuevaMarca.addEventListener('click', () => {
      document.getElementById("tituloModalMarca").textContent = "Nueva Marca";
      formMarca.reset();
      formMarca.dataset.editing = "";
      const max = marcas.length ? Math.max(...marcas.map(m => m.id_marca)) : 0;
      mId.value = max + 1;
      mActiva.checked = true;
      openModal("#modalMarca");
    });
  }

  function editarMarca(id) {
    const m = marcas.find(x => x.id_marca === id);
    if (!m) return;
    document.getElementById("tituloModalMarca").textContent = "Editar Marca";
    mId.value = m.id_marca; mId.readOnly = true;
    mNombre.value = m.nom_marca;
    mActiva.checked = !!m.estado_marca;
    formMarca.dataset.editing = String(id);
    openModal("#modalMarca");
  }

  async function desactivarMarca(id) {
    if (!await showConfirm('¿Desactivar esta marca? Los productos activos de esta marca deberán desactivarse primero.', { danger: true, confirmText: 'Desactivar', cancelText: 'Cancelar' })) return;
    try {
      const res = await secureFetch(`${API_BASE}/marcas.php`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id_marca: id })
      });
      const data = await res.json();
      if (data.ok) {
        showNotification('Marca desactivada. Puedes reactivarla desde el panel.');
        await cargarMarcas();
        await cargarCatalogosProducto();
      } else {
        showAlert(data.msg || 'No se pudo desactivar la marca', 'Bloqueo de Seguridad');
      }
    } catch (e) {
      console.error(e);
      showAlert('Error técnico al intentar desactivar marca: ' + e.message, 'Fallo Crítico');
    }
  }

  async function reactivarMarca(id) {
    const m = marcas.find(x => x.id_marca === id);
    if (!m) return;
    if (!await showConfirm('¿Reactivar esta marca? Volverá a aparecer en el catálogo.', { confirmText: 'Reactivar', cancelText: 'Cancelar' })) return;
    try {
      const res = await secureFetch(`${API_BASE}/marcas.php`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id_marca: m.id_marca, nom_marca: m.nom_marca, estado_marca: 1 })
      });
      const data = await res.json();
      if (data.ok) {
        showNotification('✅ Marca reactivada correctamente.');
        await cargarMarcas();
        await cargarCatalogosProducto();
      } else {
        showAlert(data.msg || 'Error al reactivar marca', 'Error');
      }
    } catch (e) {
      console.error(e);
      showAlert('Error técnico al reactivar: ' + e.message, 'Fallo Crítico');
    }
  }

  window.editarMarca = editarMarca;
  window.desactivarMarca = desactivarMarca;
  window.reactivarMarca = reactivarMarca;

  if (formMarca) {
    formMarca.addEventListener('submit', async (e) => {
      e.preventDefault();
      const payload = {
        id_marca: Number(mId.value),
        nom_marca: mNombre.value.trim(),
        estado_marca: mActiva.checked ? 1 : 0
      };
      const editing = formMarca.dataset.editing;
      try {
        const method = editing ? 'PUT' : 'POST';
        const res = await secureFetch(`${API_BASE}/marcas.php`, {
          method, headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        const data = await res.json();
        if (data.ok) {
          showNotification(data.msg || 'Guardado');
          closeModal("#modalMarca");
          mId.readOnly = false;
          await cargarMarcas();
          await cargarCatalogosProducto();
        } else {
          showNotification(data.msg || 'Error al guardar marca');
        }
      } catch (e2) {
        console.error(e2); showNotification('Error al guardar marca: ' + e2.message);
      }
    });
  }


  /* =======================
   * CATEGORÍAS
   * ======================= */
  const tbodyCategorias = document.getElementById("tbodyCategorias");
  const btnNuevaCategoria = document.getElementById("btnNuevaCategoria");
  const formCategoria = document.getElementById("formCategoria");
  const cId = document.getElementById("cId");
  const cNombre = document.getElementById("cNombre");
  const cDescripcion = document.getElementById("cDescripcion");
  const cActiva = document.getElementById("cActiva");
  const buscarCategoria = document.getElementById("buscarCategoria");

  async function cargarCategorias() {
    try {
      const res = await secureFetch(`${API_BASE}/categorias.php`);
      const data = await res.json();
      if (data.ok) {
        categorias = data.categorias.map(c => ({
          id_categoria: c.id_categoria,
          nom_categoria: c.nom_categoria,
          descripcion_categoria: c.descripcion_categoria ?? '',
          estado: c.estado
        }));
        drawCategorias();
        refrescarSelectsCategorias();
      }
    } catch (e) {
      console.error('Error cargando categorías:', e);
    }
  }

  /* =======================
   * CONFIGURACIÓN
   * ======================= */
  const formConfig = document.getElementById('formConfig');

  async function cargarConfiguracion() {
    try {
      const res = await secureFetch(`${API_BASE}/admin_settings.php`);
      const data = await res.json();
      if (data.ok) {
        const store = data.store || { moneda: 'COP', tasa_cambio: 1 };
        const admin = data.admin || { usuario: 'admin' };

        const elMoneda = document.getElementById('tiendaMoneda');
        const elUser = document.getElementById('adminUsuario');
        if (elMoneda) elMoneda.value = store.moneda;
        if (elUser) elUser.value = admin.usuario;

        // Actualizar globals para que las tablas del admin usen la moneda correcta
        window.MONEDA_ACTIVA = store.moneda || 'COP';
        window.TASA_CAMBIO = Number(store.tasa_cambio) || 1;
      }
    } catch (e) {
      console.error('Error cargando configuración:', e);
    }
  }

  if (formConfig) {
    formConfig.addEventListener('submit', async (e) => {
      e.preventDefault();
      const usuario = document.getElementById('adminUsuario').value.trim();
      const moneda = document.getElementById('tiendaMoneda').value;
      // Tasa automática según moneda (oculta al usuario)
      const tasasPorMoneda = { COP: 1, USD: 0.00025, EUR: 0.00023 };
      const tasaCambio = tasasPorMoneda[moneda] || 1;
      const currentPass = document.getElementById('adminCurrentPass').value;
      const newPass = document.getElementById('adminNewPass').value;

      if (!currentPass) {
        showNotification('Debes ingresar tu contraseña actual para confirmar cambios.');
        return;
      }

      try {
        const res = await secureFetch(`${API_BASE}/admin_settings.php?action=update_config`, {
          method: 'POST',
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify({ usuario, moneda, tasa_cambio: tasaCambio, current_pass: currentPass, new_pass: newPass })
        });
        const data = await res.json();
        if (data.ok) {
          showNotification(data.msg || 'Configuración actualizada correctamente.');
          document.getElementById('adminCurrentPass').value = '';
          document.getElementById('adminNewPass').value = '';
        } else {
          showNotification(data.msg || 'Error al actualizar configuración');
        }
      } catch (e) {
        console.error(e);
        showNotification('Error al guardar la configuración');
      }
    });
  }


  function drawCategorias(list = categorias) {
    if (!tbodyCategorias) return;
    tbodyCategorias.innerHTML = list.map(c => `
      <tr class="${!c.estado ? 'row-inactive' : ''}">
        <td>${c.id_categoria}</td>
        <td>${c.nom_categoria}</td>
        <td><span class="badge ${c.estado ? 'active' : 'inactive'}">${c.estado ? 'Activa' : 'Inactiva'}</span></td>
        <td class="actions">
          <button class="button button-outline" onclick="editarCategoria(${c.id_categoria})"><i class="fas fa-pen"></i></button>
          ${c.estado
            ? `<button class="button button-danger" onclick="desactivarCategoria(${c.id_categoria})" title="Desactivar"><i class="fas fa-ban"></i></button>`
            : `<button class="button button-success" onclick="reactivarCategoria(${c.id_categoria})" title="Reactivar"><i class="fas fa-undo"></i></button>`
          }
        </td>
      </tr>`).join('');
  }

  if (buscarCategoria) {
    buscarCategoria.addEventListener('input', (e) => {
      const q = e.target.value.toLowerCase();
      drawCategorias(categorias.filter(c =>
        c.nom_categoria.toLowerCase().includes(q) ||
        (c.descripcion_categoria || '').toLowerCase().includes(q)
      ));
    });
  }

  if (btnNuevaCategoria && formCategoria) {
    btnNuevaCategoria.addEventListener('click', () => {
      document.getElementById("tituloModalCategoria").textContent = "Nueva Categoría";
      formCategoria.reset();
      formCategoria.dataset.editing = "";
      const max = categorias.length ? Math.max(...categorias.map(c => c.id_categoria)) : 0;
      cId.value = max + 1;
      cActiva.checked = true;
      openModal("#modalCategoria");
    });
  }

  function editarCategoria(id) {
    const c = categorias.find(x => x.id_categoria === id);
    if (!c) return;
    document.getElementById("tituloModalCategoria").textContent = "Editar Categoría";
    cId.value = c.id_categoria; cId.readOnly = true;
    cNombre.value = c.nom_categoria;
    cDescripcion.value = c.descripcion_categoria || '';
    cActiva.checked = c.estado !== 0;
    formCategoria.dataset.editing = String(id);
    openModal("#modalCategoria");
  }

  async function desactivarCategoria(id) {
    if (!await showConfirm('¿Desactivar esta categoría? Las subcategorías y productos activos dentro deberán desactivarse primero.', { danger: true, confirmText: 'Desactivar', cancelText: 'Cancelar' })) return;
    try {
      const res = await secureFetch(`${API_BASE}/categorias.php`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ id_categoria: id })
      });
      const data = await res.json();
      if (data.ok) {
        showNotification('Categoría desactivada. Puedes reactivarla desde el panel.');
        await cargarCategorias();
        await cargarSubcategorias(getFiltroCat());
        await cargarCatalogosProducto();
      } else {
        showAlert(data.msg || 'Error al desactivar categoría', 'Bloqueo de Seguridad');
      }
    } catch (e) {
      console.error(e);
      showAlert('Error técnico al intentar desactivar categoría: ' + e.message, 'Fallo Crítico');
    }
  }

  async function reactivarCategoria(id) {
    const cat = categorias.find(x => x.id_categoria === id);
    if (!cat) return;
    if (!await showConfirm('¿Reactivar esta categoría? Volverá a estar disponible.', { confirmText: 'Reactivar', cancelText: 'Cancelar' })) return;
    try {
      const res = await secureFetch(`${API_BASE}/categorias.php`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id_categoria: cat.id_categoria,
          nom_categoria: cat.nom_categoria,
          descripcion_categoria: cat.descripcion_categoria || '',
          estado: 1
        })
      });
      const data = await res.json();
      if (data.ok) {
        showNotification('✅ Categoría reactivada correctamente.');
        await cargarCategorias();
        await cargarCatalogosProducto();
      } else {
        showAlert(data.msg || 'Error al reactivar categoría', 'Error');
      }
    } catch (e) {
      console.error(e);
      showAlert('Error técnico al reactivar: ' + e.message, 'Fallo Crítico');
    }
  }

  window.editarCategoria = editarCategoria;
  window.desactivarCategoria = desactivarCategoria;
  window.reactivarCategoria = reactivarCategoria;

  if (formCategoria) {
    formCategoria.addEventListener('submit', async (e) => {
      e.preventDefault();
      const payload = {
        id_categoria: Number(cId.value),
        nom_categoria: cNombre.value.trim(),
        descripcion_categoria: cDescripcion.value.trim(),
        estado: cActiva.checked ? 1 : 0
      };
      const editing = formCategoria.dataset.editing;
      try {
        const method = editing ? 'PUT' : 'POST';
        const res = await secureFetch(`${API_BASE}/categorias.php`, {
          method, headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });
        const data = await res.json();
        if (data.ok) {
          showNotification(data.msg || 'Guardado');
          closeModal("#modalCategoria");
          cId.readOnly = false;
          await cargarCategorias();
          await cargarCatalogosProducto();
        } else {
          showNotification(data.msg || 'Error al guardar categoría');
        }
      } catch (e2) { console.error(e2); showNotification('Error al guardar categoría: ' + e2.message); }
    });
  }


  /* =======================
   * SUBCATEGORÍAS 
   * ======================= */
  const tbodySubcategorias = document.getElementById("tbodySubcategorias");
  const btnNuevaSubcategoria = document.getElementById("btnNuevaSubcategoria");
  const formSubcategoria = document.getElementById("formSubcategoria");
  const scId = document.getElementById("scId");
  const scCategoria = document.getElementById("scCategoria");
  const scNombre = document.getElementById("scNombre");
  const filtroCatSub = document.getElementById("filtroCatSub");
  const buscarSubcategoria = document.getElementById("buscarSubcategoria");

  function getFiltroCat() {
    return filtroCatSub ? Number(filtroCatSub.value) || null : null;
  }

  async function cargarSubcategorias(catId = null) {
    try {
      const res = await secureFetch(`${API_BASE}/categorias.php?action=subcategoria`);
      const data = await res.json();

      if (data.ok) {
        subcategorias = data.subcategorias.map(s => ({
          id_subcategoria: s.id_subcategoria,
          nom_subcategoria: s.nom_subcategoria,
          id_categoria: s.id_categoria,
          nom_categoria: s.nom_categoria || '',
          estado: s.estado ?? true
        }));
        drawSubcategorias();
      } else {
        console.error('Error cargando subcategorías:', data.msg);
      }
    } catch (e) {
      console.error('Error cargando subcategorías:', e);
    }
  }

  function drawSubcategorias(list = subcategorias) {
    if (!tbodySubcategorias) return;

    const q = (buscarSubcategoria?.value || '').toLowerCase();
    const f = getFiltroCat();

    const filtered = list.filter(s =>
      (!f || s.id_categoria === f) &&
      (s.nom_subcategoria.toLowerCase().includes(q) ||
        (s.nom_categoria || '').toLowerCase().includes(q))
    );

    tbodySubcategorias.innerHTML = filtered.map(s => `
    <tr class="${!s.estado ? 'row-inactive' : ''}">
      <td>${s.id_subcategoria}</td>
      <td>${s.nom_categoria}</td>
      <td>${s.nom_subcategoria}</td>
      <td><span class="badge ${s.estado ? 'active' : 'inactive'}">${s.estado ? 'Activa' : 'Inactiva'}</span></td>
      <td class="actions">
        <button class="button button-outline" onclick="editarSubcategoria(${s.id_categoria}, ${s.id_subcategoria})"><i class="fas fa-pen"></i></button>
        ${s.estado
          ? `<button class="button button-danger" onclick="desactivarSubcategoria(${s.id_categoria}, ${s.id_subcategoria})" title="Desactivar"><i class="fas fa-ban"></i></button>`
          : `<button class="button button-success" onclick="reactivarSubcategoria(${s.id_categoria}, ${s.id_subcategoria})" title="Reactivar"><i class="fas fa-undo"></i></button>`
        }
      </td>
    </tr>`).join('');
  }

  function refrescarSelectsCategorias() {
    const opts = ['<option value="">Seleccione...</option>'].concat(
      categorias.map(c => `<option value="${c.id_categoria}">${c.nom_categoria}</option>`)
    ).join('');

    if (scCategoria) scCategoria.innerHTML = opts;

    if (filtroCatSub) {
      const all = '<option value="">Todas las categorías</option>' +
        categorias.map(c => `<option value="${c.id_categoria}">${c.nom_categoria}</option>`).join('');
      filtroCatSub.innerHTML = all;
    }
  }

  if (btnNuevaSubcategoria && formSubcategoria) {
    btnNuevaSubcategoria.addEventListener('click', () => {
      document.getElementById("tituloModalSubcategoria").textContent = "Nueva Subcategoría";
      formSubcategoria.reset();
      formSubcategoria.dataset.editing = "";
      formSubcategoria.dataset.editingCat = "";

      const max = subcategorias.length ? Math.max(...subcategorias.map(s => s.id_subcategoria)) : 0;
      scId.value = max + 1;
      scId.readOnly = false;

      openModal("#modalSubcategoria");
    });
  }

  function editarSubcategoria(idCat, idSub) {
    const s = subcategorias.find(x =>
      x.id_categoria === idCat && x.id_subcategoria === idSub
    );
    if (!s) return;

    document.getElementById("tituloModalSubcategoria").textContent = "Editar Subcategoría";
    scId.value = s.id_subcategoria;
    scId.readOnly = true;
    scNombre.value = s.nom_subcategoria;
    scCategoria.value = s.id_categoria;

    formSubcategoria.dataset.editing = String(idSub);
    formSubcategoria.dataset.editingCat = String(idCat);

    openModal("#modalSubcategoria");
  }

  async function desactivarSubcategoria(idCat, idSub) {
    if (!await showConfirm('¿Desactivar esta subcategoría? Los productos activos vinculados deberán desactivarse primero.', { danger: true, confirmText: 'Desactivar', cancelText: 'Cancelar' })) return;

    try {
      const res = await secureFetch(`${API_BASE}/categorias.php?action=subcategoria`, {
        method: 'DELETE',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id_categoria: idCat,
          id_subcategoria: idSub
        })
      });

      const data = await res.json();

      if (data.ok) {
        showNotification('Subcategoría desactivada. Puedes reactivarla desde el panel.');
        await cargarSubcategorias();
        await cargarCatalogosProducto();
      } else {
        showAlert(data.msg || 'No se pudo desactivar la subcategoría', 'Bloqueo de Seguridad');
      }
    } catch (e) {
      console.error(e);
      showAlert('Error técnico al intentar desactivar: ' + e.message, 'Fallo Crítico');
    }
  }

  async function reactivarSubcategoria(idCat, idSub) {
    const s = subcategorias.find(x => x.id_categoria === idCat && x.id_subcategoria === idSub);
    if (!s) return;
    if (!await showConfirm('¿Reactivar esta subcategoría? Volverá a estar disponible en el catálogo.', { confirmText: 'Reactivar', cancelText: 'Cancelar' })) return;
    try {
      const res = await secureFetch(`${API_BASE}/categorias.php?action=subcategoria`, {
        method: 'PUT',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({
          id_categoria: s.id_categoria,
          id_subcategoria: s.id_subcategoria,
          nom_subcategoria: s.nom_subcategoria,
          estado: true
        })
      });
      const data = await res.json();
      if (data.ok) {
        showNotification('✅ Subcategoría reactivada correctamente.');
        await cargarSubcategorias();
        await cargarCatalogosProducto();
      } else {
        showAlert(data.msg || 'Error al reactivar subcategoría', 'Error');
      }
    } catch (e) {
      console.error(e);
      showAlert('Error técnico al reactivar: ' + e.message, 'Fallo Crítico');
    }
  }

  if (buscarSubcategoria) {
    buscarSubcategoria.addEventListener('input', () => drawSubcategorias());
  }

  if (filtroCatSub) {
    filtroCatSub.addEventListener('change', () => drawSubcategorias());
  }

  if (formSubcategoria) {
    formSubcategoria.addEventListener('submit', async (e) => {
      e.preventDefault();

      // Validaciones
      const idCat = Number(scCategoria.value);
      const idSub = Number(scId.value);
      const nombre = scNombre.value.trim();

      if (!idCat) {
        showNotification('Debe seleccionar una categoría');
        return;
      }

      if (!idSub || idSub <= 0) {
        showNotification('ID de subcategoría inválido');
        return;
      }

      if (!nombre) {
        showNotification('El nombre es requerido');
        return;
      }

      const payload = {
        id_categoria: idCat,
        id_subcategoria: idSub,
        nom_subcategoria: nombre
      };

      const editing = formSubcategoria.dataset.editing;

      try {
        const method = editing ? 'PUT' : 'POST';
        const res = await secureFetch(`${API_BASE}/categorias.php?action=subcategoria`, {
          method,
          headers: { 'Content-Type': 'application/json' },
          body: JSON.stringify(payload)
        });

        const data = await res.json();

        if (data.ok) {
          showNotification(data.msg || 'Subcategoría guardada correctamente');
          closeModal("#modalSubcategoria");
          scId.readOnly = false;
          await cargarSubcategorias();
          await cargarCatalogosProducto();
        } else {
          showNotification(data.msg || 'Error al guardar subcategoría');
        }
      } catch (e2) {
        console.error(e2);
        showNotification('Error al guardar subcategoría: ' + e2.message);
      }
    });
  }

  window.editarSubcategoria = editarSubcategoria;
  window.desactivarSubcategoria = desactivarSubcategoria;
  window.reactivarSubcategoria = reactivarSubcategoria;

  /* =======================
   * GESTIÓN DE CITAS
   * ======================= */
  async function cargarCitasAdmin() {
    try {
      const res = await secureFetch(`${API_BASE}/citas.php`);
      const data = await res.json();
      if (data.ok) {
        // Citas normales de servicios técnicos
        const citasNormales = (data.citas || []).map(c => ({ ...c, tipo: 'cita' }));

        // Solicitudes del formulario de contacto → se normalizan al mismo shape
        const citasContacto = (data.contactos || []).map(c => ({
          tipo:            'contacto',
          id_reserva:      'C-' + c.id_contacto,  // Prefijo para distinguir
          cliente:         c.nombre_remitente,
          id_usuario:      null,
          nombre_servicio: c.mensaje,               // El mensaje va en la columna Servicio
          fecha_preferida: c.fecha_envio ? c.fecha_envio.substring(0, 10) : '—',
          prioridad:       'normal',
          estado:          c.estado || 'pendiente',
          // Datos extra solo disponibles en contactos
          correo:          c.correo_remitente,
          telefono:        c.telefono_remitente
        }));

        citas = [...citasNormales, ...citasContacto];
        renderCitas();
      }
    } catch (error) {
      console.error("Error al cargar citas:", error);
    }
  }

  function renderCitas(list = citas) {
    const tbody = document.getElementById('tbodyCitas');
    if (!tbody) return;

    const searchFilter = document.getElementById("buscarCita")?.value.toLowerCase() || "";
    const statusFilter = document.getElementById("filtroEstadoCita")?.value || "";
    const tipoFilter   = document.getElementById("filtroTipoCita")?.value || "";

    const filtered = (list || []).filter(cita => {
      const matchSearch = !searchFilter || (cita.cliente || '').toLowerCase().includes(searchFilter);
      const matchStatus = !statusFilter || (cita.estado || '').toLowerCase() === statusFilter.toLowerCase();
      const matchTipo   = !tipoFilter   || (cita.tipo  || 'cita') === tipoFilter;
      return matchSearch && matchStatus && matchTipo;
    });

    tbody.innerHTML = '';

    if (filtered.length === 0) {
      tbody.innerHTML = '<tr><td colspan="8" style="text-align:center;">No se encontraron citas con estos filtros.</td></tr>';
      return;
    }

    filtered.forEach(cita => {
      const tr = document.createElement('tr');

      let badgeClass = 'secondary';
      const est = (cita.estado || '').toLowerCase();
      const esContacto = cita.tipo === 'contacto';

      if (est === 'confirmada' || est === 'completada') badgeClass = 'success';
      else if (est === 'cancelada') badgeClass = 'danger';
      else if (est === 'pendiente') badgeClass = 'warning';

      // Columna «Servicio»: para contactos muestra el mensaje truncado + datos de contacto
      const celdaServicio = esContacto
        ? `<span style="color:#6c757d;font-size:0.88em;">${(cita.nombre_servicio || '').substring(0, 60)}${(cita.nombre_servicio || '').length > 60 ? '…' : ''}</span>
           <br><small style="color:#888">${cita.correo || ''} · ${cita.telefono || ''}</small>`
        : (cita.nombre_servicio || 'Servicio');

      // Badge de tipo de solicitud
      const tipoBadge = esContacto
        ? `<span style="display:inline-block;padding:2px 7px;border-radius:10px;font-size:0.72em;font-weight:700;background:#6f42c1;color:#fff;margin-bottom:3px;">CONTACTO</span><br>`
        : '';

      // Columna ID: para contactos el prefijo «C-» ya viene en id_reserva
      const celdaId = `<small style="font-size:0.85em;">#${cita.id_reserva}</small>`;

      // Columna Prioridad: contactos no tienen prioridad relevante
      const celdaPrioridad = esContacto
        ? `<span style="color:#aaa;font-size:0.85em;">—</span>`
        : `<span class="badge ${cita.prioridad === 'alta' ? 'danger' : 'primary'}" style="padding: 4px 8px; border-radius: 4px; font-weight: bold; background: ${cita.prioridad === 'alta' ? '#dc3545' : '#007bff'}; color: #fff;">${(cita.prioridad || 'normal').toUpperCase()}</span>`;

      // Acciones: contactos no tienen cambio de estado (solo visualización)
      const celdaAcciones = esContacto
        ? `<span style="color:#aaa;font-size:0.82em;">Solo lectura</span>`
        : `<div class="action-buttons" style="display: flex; gap: 8px;">
              ${est === 'pendiente' ? `
                  <button class="button button-icon" style="color:#28a745; background: none; border: 1px solid #28a745; padding: 5px 8px; border-radius: 4px; cursor: pointer;" title="Confirmar" onclick="cambiarEstadoCita(${cita.id_reserva}, 'confirmada')">
                      <i class="fas fa-check"></i>
                  </button>` : ''}
              ${est !== 'completada' && est !== 'cancelada' ? `
                  <button class="button button-icon" style="color:#b8860b; background: none; border: 1px solid #b8860b; padding: 5px 8px; border-radius: 4px; cursor: pointer;" title="Completar" onclick="cambiarEstadoCita(${cita.id_reserva}, 'completada')">
                      <i class="fas fa-check-double"></i>
                  </button>` : ''}
              ${est !== 'cancelada' ? `
                  <button class="button button-icon" style="color:#dc3545; background: none; border: 1px solid #dc3545; padding: 5px 8px; border-radius: 4px; cursor: pointer;" title="Cancelar" onclick="cambiarEstadoCita(${cita.id_reserva}, 'cancelada')">
                      <i class="fas fa-times"></i>
                  </button>` : ''}
           </div>`;

      tr.innerHTML = `
          <td>${celdaId}</td>
          <td>
              ${tipoBadge}
              <strong>${cita.cliente || 'Visitante'}</strong>${!esContacto ? `<br><small style="color:#555">ID: ${cita.id_usuario}</small>` : ''}
          </td>
          <td>${celdaServicio}</td>
          <td>${cita.fecha_preferida}</td>
          <td>${celdaPrioridad}</td>
          <td>
              <span class="badge ${badgeClass}" style="padding: 4px 8px; border-radius: 4px; font-weight: bold; background: ${badgeClass === 'success' ? '#28a745' : badgeClass === 'warning' ? '#ffc107' : badgeClass === 'danger' ? '#dc3545' : '#6c757d'}; color: ${badgeClass === 'warning' ? '#000' : '#fff'};"> ${est.toUpperCase()}</span>
          </td>
          <td>
              <span style="color: #999;">- Sin adjuntos -</span>
          </td>
          <td>${celdaAcciones}</td>
      `;
      tbody.appendChild(tr);
    });
  }

  // Listeners para Citas
  document.getElementById("buscarCita")?.addEventListener("input", () => renderCitas());
  document.getElementById("filtroEstadoCita")?.addEventListener("change", () => renderCitas());
  document.getElementById("filtroTipoCita")?.addEventListener("change", () => renderCitas());

  window.cambiarEstadoCita = async function (idReserva, nuevoEstado) {
    if (!await showConfirm(`¿Estás seguro de marcar esta cita como "${nuevoEstado}"?`, { confirmText: 'Confirmar', cancelText: 'Cancelar' })) return;

    try {
      const res = await secureFetch(`${API_BASE}/citas.php`, {
        method: 'PUT',
        headers: {
          'Content-Type': 'application/json'
        },
        body: JSON.stringify({
          id_reserva: idReserva,
          estado: nuevoEstado
        })
      });

      const data = await res.json();
      if (data.ok) {
        showNotification(`✅ Cita actualizada a: ${nuevoEstado}`);
        cargarCitasAdmin(); // Recargar lista
      } else {
        showNotification(`❌ Error: ${data.msg}`);
      }
    } catch (error) {
      console.error("Error al actualizar cita:", error);
      showNotification("❌ Error de conexión");
    }
  };

  /* =======================
   * INIT
   * ======================= */
  async function init() {
    await Promise.all([
      cargarProductos(),
      cargarServicios(),
      cargarMarcas(),
      cargarCategorias(),
      cargarClientes(),
      cargarPedidos(),
      cargarCitasAdmin(), // NUEVO
      cargarConfiguracion(),
      cargarEstadisticas()
    ]);

    await cargarSubcategorias();
    renderDashboard();

    const btnLogout = document.getElementById("btn-logout");
    if (btnLogout) {
      btnLogout.addEventListener("click", cerrarSesion);
    }
  }
  init();

  // ============================================
  // LOGICA MENÚ MOVIL ADMIN
  // ============================================
  const mobileMenuBtn = document.querySelector('.mobile-menu-btn');
  const adminSidebar = document.querySelector('.admin-sidebar');
  let overlay = document.querySelector('.admin-sidebar-overlay');

  if (!overlay) {
      overlay = document.createElement('div');
      overlay.className = 'admin-sidebar-overlay';
      document.body.appendChild(overlay);
  }

  if (mobileMenuBtn && adminSidebar) {
      // Toggle al presionar hamburguesa
      mobileMenuBtn.addEventListener('click', () => {
          adminSidebar.classList.toggle('open');
          overlay.classList.toggle('show');
      });

      // Cerrar al clickear en el fondo oscuro
      overlay.addEventListener('click', () => {
          adminSidebar.classList.remove('open');
          overlay.classList.remove('show');
      });

      // Cerrar menú al clickear un enlace (para móviles)
      const adminLinks = document.querySelectorAll('.admin-link');
      adminLinks.forEach(link => {
          link.addEventListener('click', () => {
              if (window.innerWidth <= 860) {
                  adminSidebar.classList.remove('open');
                  overlay.classList.remove('show');
              }
          });
      });
  }
});