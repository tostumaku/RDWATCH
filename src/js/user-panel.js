/**
 * PANEL DE USUARIO - RD WATCH
 * Gestión completa de perfil, pedidos, direcciones y pagos
 */

const API_BASE = API_CONFIG.baseUrl;
let currentUser = null;

// ==========================================
// INICIALIZACIÓN Y AUTENTICACIÓN
// ==========================================
(function checkAuth() {
    const userData = sessionStorage.getItem('user');
    if (!userData) {
        window.location.href = 'index.html';
        return;
    }

    try {
        currentUser = JSON.parse(userData);
        const uid = currentUser.id || currentUser.id_usuario;

        // UI Header
        if (document.getElementById('userName')) {
            document.getElementById('userName').textContent = currentUser.nombre.split(' ')[0];
        }

        // Cargar datos iniciales
        cargarDatosPerfil(uid);
        cargarDireccion(uid);
        cargarPedidos(uid);
        cargarMetodoPago(uid);
        cargarMetodosPagoDisponibles();

    } catch (err) {
        console.error('Error auth:', err);
        window.location.href = 'index.html';
    }
})();

// ==========================================
// FUNCIONES DE CARGA (GET)
// ==========================================
async function cargarDatosPerfil(uid) {
    try {
        const res = await fetch(`${API_BASE}/user_actions.php?action=perfil&uid=${uid}`);
        const data = await res.json();

        if (data.ok && data.data) {
            document.getElementById('inputNombre').value = data.data.nom_usuario;
            document.getElementById('inputEmail').value = data.data.correo_usuario;
            document.getElementById('inputTelefono').value = data.data.num_telefono_usuario;

            // Actualizar cards de inicio
            document.getElementById('perfilNombre').textContent = data.data.nom_usuario;
            document.getElementById('perfilEmail').textContent = data.data.correo_usuario;
        }
    } catch (e) {
        console.error('Error cargando perfil:', e);
    }
}

async function cargarDireccion(uid) {
    try {
        const res = await fetch(`${API_BASE}/user_actions.php?action=direccion&uid=${uid}`);
        const data = await res.json();

        if (data.ok && data.data) {
            const dir = data.data.direccion_completa || 'Sin registrar';
            document.getElementById('direccionPrincipal').textContent = dir;
            document.getElementById('inputDireccion').value = data.data.direccion_completa || '';
            document.getElementById('inputPostal').value = data.data.codigo_postal || '';
        } else {
            document.getElementById('direccionPrincipal').textContent = 'Sin registrar';
        }
    } catch (e) {
        console.error('Error cargando dirección:', e);
    }
}

async function cargarPedidos(uid) {
    try {
        const res = await fetch(`${API_BASE}/user_actions.php?action=pedidos&uid=${uid}`);
        const data = await res.json();
        const tbody = document.getElementById('listaPedidos');

        if (tbody && data.ok) {
            if (data.data.length === 0) {
                tbody.innerHTML = '<tr><td colspan="5" style="text-align:center">No tienes pedidos registrados</td></tr>';
                document.getElementById('totalPedidos').textContent = '0';
                return;
            }

            tbody.innerHTML = data.data.map(p => `
                <tr>
                    <td>#${p.id_orden}</td>
                    <td>${p.concepto || 'Pedido'}</td>
                    <td>${new Date(p.fecha_orden).toLocaleDateString()}</td>
                    <td>$${parseFloat(p.total_orden).toLocaleString('es-CO')}</td>
                    <td><span class="badge ${getBadgeClass(p.estado_orden)}">${p.estado_orden}</span></td>
                </tr>
            `).join('');

            document.getElementById('totalPedidos').textContent = data.data.length;
        }
    } catch (e) {
        console.error('Error cargando pedidos:', e);
    }
}

async function cargarMetodoPago(uid) {
    try {
        const res = await fetch(`${API_BASE}/user_actions.php?action=metodo_pago&uid=${uid}`);
        const data = await res.json();

        if (data.ok && data.data) {
            const info = `${data.data.nombre_metodo} - **** ${data.data.num_tarjeta}`;
            document.getElementById('pagoInfo').textContent = info;
            document.getElementById('inputTarjeta').value = data.data.num_tarjeta || '';

            // Convertir fecha DATE a MM/YYYY
            if (data.data.fecha_vencimiento) {
                const fecha = new Date(data.data.fecha_vencimiento);
                const mes = String(fecha.getMonth() + 1).padStart(2, '0');
                const anio = fecha.getFullYear();
                document.getElementById('inputExpiracion').value = `${mes}/${anio}`;
            }
        }
    } catch (e) {
        console.error('Error cargando método de pago:', e);
    }
}

async function cargarMetodosPagoDisponibles() {
    try {
        const res = await fetch(`${API_BASE}/catalogos.php?tipo=metodos_pago`);
        const data = await res.json();

        const select = document.getElementById('inputMetodoPago');
        if (select && data.ok) {
            select.innerHTML = '<option value="">Seleccione...</option>' +
                data.metodos_pago.map(m =>
                    `<option value="${m.id_metodo_pago}">${m.nombre_metodo}</option>`
                ).join('');
        }
    } catch (e) {
        console.error('Error cargando métodos de pago:', e);
        // Fallback: métodos comunes
        const select = document.getElementById('inputMetodoPago');
        if (select) {
            select.innerHTML = `
                <option value="">Seleccione...</option>
                <option value="1">Tarjeta de Crédito/Débito</option>
                <option value="2">PayPal</option>
                <option value="3">PSE</option>
            `;
        }
    }
}

// ==========================================
// LISTENERS DE FORMULARIOS
// ==========================================
document.addEventListener('DOMContentLoaded', () => {

    // --- GUARDAR PERFIL ---
    const formPerfil = document.getElementById('formPerfil');
    if (formPerfil) {
        formPerfil.addEventListener('submit', async (e) => {
            e.preventDefault();

            const uid = currentUser.id || currentUser.id_usuario;
            const payload = {
                uid: uid,
                action: 'update_profile',
                nombre: document.getElementById('inputNombre').value,
                telefono: document.getElementById('inputTelefono').value
            };

            // Cambio de contraseña (opcional)
            const pOld = document.getElementById('inputPassActual').value;
            const pNew = document.getElementById('inputPassNueva').value;

            if (pOld && pNew) {
                const resPass = await fetch(`${API_BASE}/user_actions.php`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify({
                        uid: uid,
                        action: 'change_password',
                        old_pass: pOld,
                        new_pass: pNew
                    })
                });
                const dataPass = await resPass.json();
                if (!dataPass.ok) {
                    showNotification('❌ ' + dataPass.msg, true);
                    return;
                }
            }

            try {
                const res = await fetch(`${API_BASE}/user_actions.php`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });
                const data = await res.json();

                if (data.ok) {
                    showNotification('✅ Perfil actualizado');
                    await cargarDatosPerfil(uid);
                    setTimeout(() => showSection('inicio'), 1000);
                } else {
                    showNotification('❌ ' + data.msg, true);
                }
            } catch (err) {
                showNotification('Error de conexión', true);
            }
        });
    }

    // --- GUARDAR DIRECCIÓN ---
    const formDireccion = document.getElementById('formDireccion');
    if (formDireccion) {
        formDireccion.addEventListener('submit', async (e) => {
            e.preventDefault();

            const uid = currentUser.id || currentUser.id_usuario;
            const payload = {
                uid: uid,
                action: 'update_address',
                direccion: document.getElementById('inputDireccion').value,
                postal: document.getElementById('inputPostal').value
            };

            try {
                const res = await fetch(`${API_BASE}/user_actions.php`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });
                const data = await res.json();

                if (data.ok) {
                    showNotification('✅ Dirección guardada');
                    await cargarDireccion(uid);
                    setTimeout(() => showSection('inicio'), 1000);
                } else {
                    showNotification('❌ ' + data.msg, true);
                }
            } catch (err) {
                console.error(err);
                showNotification('Error de conexión', true);
            }
        });
    }

    // --- ACTUALIZAR MÉTODO DE PAGO ---
    const formPago = document.getElementById('formPago');
    if (formPago) {
        formPago.addEventListener('submit', async (e) => {
            e.preventDefault();

            const uid = currentUser.id || currentUser.id_usuario;
            const payload = {
                uid: uid,
                action: 'update_payment',
                id_metodo_pago: document.getElementById('inputMetodoPago').value,
                num_tarjeta: document.getElementById('inputTarjeta').value,
                fecha_vencimiento: document.getElementById('inputExpiracion').value
            };

            try {
                const res = await fetch(`${API_BASE}/user_actions.php`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });
                const data = await res.json();

                if (data.ok) {
                    showNotification('✅ Método de pago actualizado');
                    await cargarMetodoPago(uid);
                    setTimeout(() => showSection('inicio'), 1000);
                } else {
                    showNotification('❌ ' + data.msg, true);
                }
            } catch (err) {
                console.error(err);
                showNotification('Error de conexión', true);
            }
        });
    }

    // --- SOLICITUD DE SERVICIO ---
    const formServicio = document.getElementById('formSolicitudServicio');
    if (formServicio) {
        formServicio.addEventListener('submit', async (e) => {
            e.preventDefault();

            const uid = currentUser.id || currentUser.id_usuario;
            const payload = {
                p_id_usuario: uid,
                p_id_servicio: document.getElementById('servicioSeleccionadoId').value,
                p_fecha_pref: document.getElementById('fechaPreferida').value,
                p_notas: document.getElementById('notasServicio').value
            };

            try {
                const res = await fetch(`${API_BASE}/citas.php`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });
                const data = await res.json();

                if (data.ok) {
                    showNotification('✅ ' + data.msg);
                    formServicio.reset();
                    formServicio.classList.add('hidden');
                    setTimeout(() => showSection('inicio'), 1500);
                } else {
                    showNotification('❌ ' + data.msg, true);
                }
            } catch (err) {
                showNotification('Error de conexión', true);
            }
        });
    }

    // --- ENVIAR RESEÑA ---
    const formResena = document.getElementById('formResena');
    if (formResena) {
        formResena.addEventListener('submit', async (e) => {
            e.preventDefault();

            const uid = currentUser.id || currentUser.id_usuario;
            const rating = document.querySelector('input[name="rating"]:checked');

            if (!rating) {
                showNotification('❌ Debes seleccionar una calificación', true);
                return;
            }

            const payload = {
                id_usuario: uid,
                calificacion: parseInt(rating.value),
                comentario: document.getElementById('resenaTexto').value
            };

            try {
                const res = await fetch(`${API_BASE}/resenas.php`, {
                    method: 'POST',
                    headers: { 'Content-Type': 'application/json' },
                    body: JSON.stringify(payload)
                });
                const data = await res.json();

                if (data.ok) {
                    showNotification('✅ ¡Gracias por tu opinión!');
                    formResena.reset();
                    setTimeout(() => showSection('inicio'), 1500);
                } else {
                    showNotification('❌ ' + data.msg, true);
                }
            } catch (err) {
                showNotification('Error de conexión', true);
            }
        });
    }

    // --- NAVEGACIÓN ---
    document.querySelectorAll('.nav-link').forEach(link => {
        link.addEventListener('click', (e) => {
            e.preventDefault();
            document.querySelectorAll('.nav-link').forEach(l => l.classList.remove('active'));
            link.classList.add('active');
            const section = link.dataset.section || link.getAttribute('data-section');
            if (section) showSection(section);
        });
    });

    // --- LOGOUT ---
    document.getElementById('logoutLink')?.addEventListener('click', (e) => {
        e.preventDefault();
        if (confirm('¿Cerrar sesión?')) {
            sessionStorage.removeItem('user');
            window.location.href = '/RD_WATCH/frontend/public/index.html';
        }
    });
});

// ==========================================
// UTILIDADES
// ==========================================
function showSection(id) {
    document.querySelectorAll('.form-section, .welcome-section').forEach(el => {
        el.style.display = 'none';
    });
    const el = document.getElementById(id);
    if (el) el.style.display = 'block';
}

function showNotification(msg, isError = false) {
    const n = document.getElementById('notification');
    if (!n) return;
    n.textContent = msg;
    n.className = isError ? 'notification error show' : 'notification success show';
    setTimeout(() => n.classList.remove('show'), 4000);
}

function getBadgeClass(estado) {
    const e = estado.toLowerCase();
    if (e.includes('pendiente')) return 'pendiente';
    if (e.includes('pagado') || e.includes('completado')) return 'completado';
    if (e.includes('enviado')) return 'enviado';
    if (e.includes('cancelado')) return 'cancelado';
    return 'inactive';
}

// Funciones globales para botones onclick
window.showSection = showSection;

window.seleccionarServicio = (nombre, id) => {
    document.getElementById('servicioSeleccionado').value = nombre;
    document.getElementById('servicioSeleccionadoId').value = id;
    document.getElementById('formSolicitudServicio').classList.remove('hidden');
};

window.cancelarSolicitud = () => {
    document.getElementById('formSolicitudServicio').classList.add('hidden');
};