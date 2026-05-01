// 🔒 CONSTANTE BASE URL
const API_BASE_URL = API_CONFIG.baseUrl;

// La seguridad ahora se gestiona globalmente mediante security.js

// 🔒 OBTENER USUARIO DE LA SESIÓN
function getUser() {
    const userData = sessionStorage.getItem('user');
    if (!userData) return null;
    try {
        return JSON.parse(userData);
    } catch (err) {
        console.error('Error al parsear usuario:', err);
        return null;
    }
}

// 🛡️ PROTECCIÓN LOCAL DE CACHÉ BROWSER (bfcache)
window.addEventListener('pageshow', function (event) {
    if (event.persisted) {
        window.location.reload();
    } else {
        const user = sessionStorage.getItem('user');
        const appUrl = (typeof API_CONFIG !== 'undefined' && API_CONFIG.appUrl) ? API_CONFIG.appUrl : '../../';
        if (!user) {
            window.location.replace(`${appUrl}/index.html`);
        }
    }
});

// 🔒 VERIFICACIÓN DE AUTENTICACIÓN Y CARGA INICIAL DE DATOS
(async function checkAuth() {
    const user = getUser();
    const appUrl = (typeof API_CONFIG !== 'undefined' && API_CONFIG.appUrl) ? API_CONFIG.appUrl : '../../';

    if (!user) {
        showNotification('⚠️ Debes iniciar sesión para acceder a tu panel');
        window.location.replace(`${appUrl}/index.html`);
        return;
    }

    // 🛡️ VERIFICACIÓN DEL LADO DEL SERVIDOR
    // Aunque sessionStorage tenga datos, verificamos que la sesión PHP siga activa.
    // Esto previene el acceso por caché del navegador después de cerrar sesión.
    try {
        const sessionCheck = await secureFetch(`${API_BASE_URL}/me.php`, { method: 'GET' });
        const sessionData = await sessionCheck.json();
        if (!sessionData.ok || !sessionData.user) {
            sessionStorage.removeItem('user');
            showNotification('⚠️ Tu sesión ha expirado. Inicia sesión nuevamente.');
            window.location.replace(`${appUrl}/index.html`);
            return;
        }
    } catch (err) {
        console.error('Error verificando sesión del servidor:', err);
        sessionStorage.removeItem('user');
        window.location.replace(`${appUrl}/index.html`);
        return;
    }

    fetchCsrfToken(); // 🛡️ Restaurado con token estático para estabilidad

    try {
        const userNameEl = document.getElementById('userName');
        if (userNameEl) {
            userNameEl.textContent = user.nombre.split(' ')[0];
        }

        if (user.rol === 'admin') {
            const welcomeSection = document.querySelector('.welcome-section');
            if (welcomeSection) {
                const adminAlert = document.createElement('div');
                adminAlert.style.cssText = 'background: var(--primary-color); color: var(--white); padding: 15px; border-radius: 8px; margin-bottom: 20px; text-align: center;';
                adminAlert.innerHTML = `
                    <strong>👑 Eres administrador</strong>
                    <br><br>
                    <a href="../admin/admin.html" style="color: var(--white); text-decoration: underline;">
                        Ir al Panel de Administración →
                    </a>
                `;
                welcomeSection.insertBefore(adminAlert, welcomeSection.firstChild);
            }
        }

        await cargarDatosPerfil(user.id);
        await cargarPedidos(user.id);
        await cargarCitas(user.id);

    } catch (err) {
        console.error('Error al verificar usuario:', err);
        showNotification('❌ Sesión inválida');
        window.location.replace(`${appUrl}/index.html`);
    }
})();

// 🔄 CARGAR DATOS DEL PERFIL DESDE EL BACKEND
async function cargarDatosPerfil(userId) {
    try {
        const response = await secureFetch(`${API_BASE_URL}/user_actions.php?action=perfil&uid=${userId}`, {
            method: 'GET'
        });
        const result = await response.json();
        if (result.ok && result.data) {
            const perfilNombre = document.getElementById('perfilNombre');
            const perfilEmail = document.getElementById('perfilEmail');
            const inputNombre = document.getElementById('inputNombre');
            const inputEmail = document.getElementById('inputEmail');
            const inputTelefono = document.getElementById('inputTelefono');
            const direccionPrincipal = document.getElementById('direccionPrincipal');

            if (perfilNombre) perfilNombre.textContent = result.data.nom_usuario || '';
            if (perfilEmail) perfilEmail.textContent = result.data.correo_usuario || '';
            if (inputNombre) inputNombre.value = result.data.nom_usuario || '';
            if (inputEmail) inputEmail.value = result.data.correo_usuario || '';
            if (inputTelefono) inputTelefono.value = result.data.num_telefono_usuario || '';
            if (direccionPrincipal) direccionPrincipal.textContent = result.data.direccion_principal || 'No configurada';
        }
    } catch (error) {
        console.error('Error al cargar datos del perfil:', error);
    }
}

// 🔄 CARGAR PEDIDOS DEL USUARIO
async function cargarPedidos(userId) {
    try {
        const response = await secureFetch(`${API_BASE_URL}/user_actions.php?action=pedidos&uid=${userId}`, {
            method: 'GET'
        });
        const result = await response.json();
        if (result.ok && result.data) {
            const pedidos = result.data;

            // Actualizar contadores del panel de inicio
            const pedidosActivosEl = document.getElementById('pedidosActivos');
            const pedidosCompletadosEl = document.getElementById('pedidosCompletados');
            
            if (pedidosActivosEl && pedidosCompletadosEl) {
                const completados = pedidos.filter(p => {
                    const est = (p.estado_orden || '').toLowerCase();
                    return est === 'completado' || est === 'entregado' || est === 'finalizado';
                }).length;
                
                const cancelados = pedidos.filter(p => {
                    const est = (p.estado_orden || '').toLowerCase();
                    return est === 'cancelado' || est === 'anulado';
                }).length;

                const activos = pedidos.length - completados - cancelados;

                pedidosActivosEl.textContent = `${activos} pedido${activos !== 1 ? 's' : ''} activo${activos !== 1 ? 's' : ''}`;
                pedidosCompletadosEl.textContent = `${completados} completado${completados !== 1 ? 's' : ''}`;
                
                if (activos > 0) pedidosActivosEl.style.color = 'var(--primary-color)';
                else pedidosActivosEl.style.color = '';
            }

            const tbodyPedidos = document.getElementById('tbodyPedidos');
            if (!tbodyPedidos) return;

            if (pedidos.length === 0) {
                tbodyPedidos.innerHTML = `
                    <tr>
                        <td colspan="5" style="text-align:center; padding: 40px; color: #888;">
                            <i class="fas fa-inbox" style="font-size: 48px; margin-bottom: 10px; display: block;"></i>
                            No tienes pedidos registrados
                        </td>
                    </tr>
                `;
                return;
            }

            tbodyPedidos.innerHTML = pedidos.map(pedido => {
                const estado = pedido.estado_orden || 'pendiente';
                const badgeClass = getBadgeClass(estado);
                const total = parseFloat(pedido.total_orden || 0);

                return `
                    <tr>
                        <td><strong>#${pedido.id_orden}</strong></td>
                        <td>${pedido.concepto || 'Pedido de productos'}</td>
                        <td>${formatFecha(pedido.fecha)}</td>
                        <td style="font-weight: bold;">$${total.toFixed(2)}</td>
                        <td><span class="badge ${badgeClass}">${capitalizeFirst(estado)}</span></td>
                    </tr>
                `;
            }).join('');
        }
    } catch (error) {
        console.error('Error al cargar pedidos:', error);
    }
}

// 🔄 CARGAR CITAS DEL USUARIO
async function cargarCitas(userId) {
    try {
        const response = await secureFetch(`${API_BASE_URL}/citas.php`, {
            method: 'GET'
        });
        const result = await response.json();
        if (result.ok) {
            const citas = result.citas || []; // null → [] si aún no hay citas
            const tbodyCitas = document.getElementById('tbodyCitas');

            // Siempre actualizar el contador del panel de inicio
            const citasPendientes = citas.filter(c => c.estado === 'pendiente' || c.estado === 'confirmada').length;
            const citasActivasEl = document.getElementById('citasActivas');
            if (citasActivasEl) {
                if (citasPendientes > 0) {
                    citasActivasEl.textContent = `${citasPendientes} cita${citasPendientes !== 1 ? 's' : ''} pendiente${citasPendientes !== 1 ? 's' : ''}`;
                    citasActivasEl.style.color = 'var(--primary-color)';
                } else {
                    citasActivasEl.textContent = '0 citas pendientes';
                    citasActivasEl.style.color = '';
                }
            }

            if (!tbodyCitas) return;

            if (citas.length === 0) {
                tbodyCitas.innerHTML = `
                    <tr>
                        <td colspan="5" style="text-align:center; padding: 40px; color: #888;">
                            <i class="fas fa-calendar-times" style="font-size: 48px; margin-bottom: 10px; display: block;"></i>
                            No tienes citas registradas
                        </td>
                    </tr>
                `;
                return;
            }

            tbodyCitas.innerHTML = citas.map(cita => {
                const estado = cita.estado || 'pendiente';
                const badgeClass = getBadgeClass(estado);
                return `
                    <tr>
                        <td><strong>${cita.nombre_servicio || 'Servicio'}</strong></td>
                        <td>${cita.fecha_preferida || 'N/A'}</td>
                        <td><span class="badge ${cita.prioridad === 'alta' ? 'cancelado' : 'enviado'}">${capitalizeFirst(cita.prioridad)}</span></td>
                        <td><span class="badge ${badgeClass}">${capitalizeFirst(estado)}</span></td>
                        <td style="font-size: 0.9em; max-width: 200px; white-space: nowrap; overflow: hidden; text-overflow: ellipsis;" title="${cita.notas || ''}">
                            ${cita.notas || '-'}
                        </td>
                    </tr>
                `;
            }).join('');
        }
    } catch (error) {
        console.error('Error al cargar citas:', error);
    }
}

// Función auxiliar para determinar clase de badge según estado
function getBadgeClass(estado) {
    const estadoLower = estado.toLowerCase();
    if (estadoLower.includes('confirmado')) return 'confirmado'; // Azul
    if (estadoLower.includes('enviado')) return 'enviado'; // Verde
    if (estadoLower.includes('cancelado')) return 'cancelado'; // Rojo
    return 'pendiente'; // Amarillo
}

// Función auxiliar para capitalizar primera letra
function capitalizeFirst(str) {
    if (!str) return '';
    return str.charAt(0).toUpperCase() + str.slice(1).toLowerCase();
}

// Función auxiliar para formatear fechas ISO → 'DD/MM/YYYY HH:MM'
function formatFecha(fechaStr) {
    if (!fechaStr) return 'N/A';
    // Reemplazar la 'T' del formato ISO 8601 por espacio y recortar milisegundos
    const clean = fechaStr.replace('T', ' ').split('.')[0]; // '2026-04-20 20:39:12'
    const [datePart, timePart] = clean.split(' ');
    if (!datePart) return fechaStr;
    const [y, m, d] = datePart.split('-');
    const time = timePart ? timePart.substring(0, 5) : ''; // 'HH:MM'
    return `${d}/${m}/${y}${time ? ' ' + time : ''}`;
}

// 🌆 CARGAR DEPARTAMENTOS Y CIUDADES
async function cargarDepartamentos() {
    try {
        const response = await secureFetch(`${API_BASE_URL}/ciudades.php?action=departamentos`);
        const result = await response.json();
        if (result.ok) {
            const selectDepto = document.getElementById('inputDepartamento');
            if (selectDepto) {
                selectDepto.innerHTML = '<option value="">Seleccione departamento...</option>' +
                    result.departamentos.map(d => `<option value="${d.id_departamento}">${d.nombre_departamento}</option>`).join('');
            }
        }
    } catch (error) {
        console.error('Error al cargar departamentos:', error);
    }
}

async function cargarCiudadesPorDepto(idDepartamento) {
    try {
        const response = await secureFetch(`${API_BASE_URL}/ciudades.php?action=ciudades&id_departamento=${idDepartamento}`);
        const result = await response.json();
        if (result.ok) {
            const selectCiudad = document.getElementById('inputCiudad');
            if (selectCiudad) {
                selectCiudad.innerHTML = '<option value="">Seleccione ciudad...</option>' +
                    result.ciudades.map(c => `<option value="${c.id_ciudad}" data-postal="${c.codigo_postal || ''}">${c.nombre_ciudad}</option>`).join('');
                selectCiudad.disabled = false;
            }
        }
    } catch (error) {
        console.error('Error al cargar ciudades:', error);
    }
}

// 🚪 CERRAR SESIÓN
async function cerrarSesion() {
    const ok = await showConfirm('¿Deseas cerrar sesión?', {
        confirmText: 'Cerrar sesión',
        cancelText: 'Cancelar'
    });
    if (!ok) return;

    // 🛡️ Limpiar sesión local PRIMERO (antes de llamar al servidor)
    // Esto garantiza que si el usuario presiona Atrás, no haya datos de sesión
    sessionStorage.clear();
    localStorage.removeItem('csrf_token');

    // Luego invalidar la sesión en el servidor
    secureFetch(`${API_BASE_URL}/logout.php`, { method: 'POST' })
        .then(res => res.json())
        .catch(() => { })
        .finally(() => {
            // replace() elimina esta página del historial del navegador
            window.location.replace(`${API_CONFIG.appUrl}/index.html`);
        });
}

// La función showNotification ahora se carga globalmente desde notifications.js

// 📄 MOSTRAR SECCIÓN
function showSection(sectionId) {
    document.querySelectorAll('.welcome-section, .form-section').forEach(section => {
        section.classList.remove('active');
        section.style.display = 'none';
    });
    if (sectionId === 'inicio') {
        const inicioEl = document.getElementById('inicio');
        if (inicioEl) inicioEl.style.display = 'block';
    } else {
        const section = document.getElementById(sectionId);
        if (section) {
            section.classList.add('active');
            section.style.display = 'block';
        }
    }
    document.querySelectorAll('.nav-link').forEach(link => {
        link.classList.remove('active');
        if (link.getAttribute('data-section') === sectionId) link.classList.add('active');
    });
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

// 📅 INICIALIZACIÓN DOM
document.addEventListener('DOMContentLoaded', async () => {
    const btnMap = {
        'btnResena': 'resenaForm',
        'btnEditarPerfil': 'perfilForm',
        'btnHistorial': 'pedidoForm',
        'btnDirecciones': 'direccionForm',
        'btnSolicitarServicio': 'servicioForm',
        'btnCitasHistorial': 'citaForm'
    };

    Object.keys(btnMap).forEach(id => {
        const btn = document.getElementById(id);
        if (btn) btn.addEventListener('click', () => showSection(btnMap[id]));
    });

    // Recargar citas cada vez que se abre el historial de citas
    const btnCitasHistorial = document.getElementById('btnCitasHistorial');
    if (btnCitasHistorial) {
        btnCitasHistorial.addEventListener('click', () => cargarCitas());
    }
    // También recargar si se navega desde el nav link de Citas
    document.querySelectorAll('.nav-link[data-section="citaForm"]').forEach(link => {
        link.addEventListener('click', () => cargarCitas());
    });

    document.querySelectorAll('.btn-cancelar').forEach(btn => {
        btn.addEventListener('click', () => showSection('inicio'));
    });

    const forms = [
        { id: 'formPerfil', handler: guardarPerfil },
        { id: 'formDireccion', handler: guardarDireccion },
        { id: 'formResena', handler: enviarResena }
    ];

    forms.forEach(item => {
        const f = document.getElementById(item.id);
        if (f) f.addEventListener('submit', (e) => item.handler(e));
    });

    document.querySelectorAll('.nav-link').forEach(link => {
        link.addEventListener('click', (e) => {
            const section = link.getAttribute('data-section');
            if (link.id === 'logoutLink') {
                e.preventDefault();
                cerrarSesion();
                return;
            }
            if (section) {
                e.preventDefault();
                showSection(section);
            }
        });
    });

    const fechaInput = document.getElementById('fechaPreferida');
    if (fechaInput) {
        // Anticipación mínima: 2 días desde hoy
        const minDate = new Date();
        minDate.setDate(minDate.getDate() + 2);
        // Si cae en domingo, mover al lunes
        if (minDate.getDay() === 0) minDate.setDate(minDate.getDate() + 1);
        const minDateStr = minDate.toISOString().split('T')[0];
        fechaInput.min = minDateStr;
        fechaInput.value = minDateStr;

        // Bloquear domingos en el selector de fecha
        fechaInput.addEventListener('input', function () {
            const selected = new Date(this.value + 'T12:00:00');
            if (selected.getDay() === 0) {
                showNotification('⚠️ Los domingos no están disponibles. Se ajustó al lunes siguiente.', true);
                selected.setDate(selected.getDate() + 1);
                this.value = selected.toISOString().split('T')[0];
            }
        });
    }

    const inputDepartamento = document.getElementById('inputDepartamento');
    if (inputDepartamento) {
        inputDepartamento.addEventListener('change', (e) => {
            const idDepto = e.target.value;
            if (idDepto) cargarCiudadesPorDepto(idDepto);
        });
    }

    const inputCiudad = document.getElementById('inputCiudad');
    if (inputCiudad) {
        inputCiudad.addEventListener('change', (e) => {
            const selectedOption = e.target.options[e.target.selectedIndex];
            const postal = selectedOption.getAttribute('data-postal');
            const inputPostal = document.getElementById('inputPostal');
            if (postal && inputPostal) inputPostal.value = postal;
        });
    }

    const servicesGrid = document.getElementById('user-services-grid');
    if (servicesGrid) {
        servicesGrid.addEventListener('click', (e) => {
            const btn = e.target.closest('.btn-solicitar-servicio');
            if (btn) {
                seleccionarServicio(
                    btn.getAttribute('data-nombre'),
                    btn.getAttribute('data-id'),
                    btn.getAttribute('data-precio'),
                    btn.getAttribute('data-duracion')
                );
            }
        });
    }

    const mobileMenuBtn = document.querySelector('.mobile-menu-btn');
    const mainNav = document.querySelector('.main-nav');
    if (mobileMenuBtn && mainNav) {
        mobileMenuBtn.addEventListener('click', () => {
            const isActive = mainNav.classList.toggle('active');
            mobileMenuBtn.innerHTML = isActive ? '<i class="fas fa-times"></i>' : '<i class="fas fa-bars"></i>';
        });

        // Cerrar menú al hacer clic en un enlace
        const navLinks = mainNav.querySelectorAll('.nav-link');
        navLinks.forEach(link => {
            link.addEventListener('click', () => {
                if (window.innerWidth <= 992) {
                    mainNav.classList.remove('active');
                    mobileMenuBtn.innerHTML = '<i class="fas fa-bars"></i>';
                }
            });
        });
    }

    showSection('inicio');

    try {
        await cargarDepartamentos();
        await cargarServiciosPanel();
    } catch (err) {
        console.error("Error cargando datos iniciales:", err);
    }
});

async function guardarPerfil(e) {
    e.preventDefault();
    const user = getUser();
    if (!user) { showNotification('❌ Error de sesión', true); return; }

    const nombre = document.getElementById('inputNombre').value;
    const email = document.getElementById('inputEmail').value;
    const telefono = document.getElementById('inputTelefono').value;

    try {
        // Cambio de contraseña (opcional) - si existen los campos
        const pOld = document.getElementById('inputPassActual')?.value;
        const pNew = document.getElementById('inputPassNueva')?.value;

        if (pOld && pNew) {
            const resPass = await secureFetch(`${API_BASE_URL}/user_actions.php`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({
                    uid: user.id,
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
            showNotification('✅ Contraseña actualizada');
        }

        // Actualizar perfil
        const response = await secureFetch(`${API_BASE_URL}/user_actions.php`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'update_profile', uid: user.id, nombre, email, telefono })
        });
        const result = await response.json();
        if (result.ok) {
            document.getElementById('perfilNombre').textContent = nombre;
            document.getElementById('userName').textContent = nombre.split(' ')[0];
            const perfilEmailEl = document.getElementById('perfilEmail');
            if (perfilEmailEl) perfilEmailEl.textContent = email;
            user.nombre = nombre;
            user.correo = email;
            sessionStorage.setItem('user', JSON.stringify(user));
            showNotification('✅ Perfil actualizado correctamente');
            setTimeout(() => showSection('inicio'), 1500);
        } else {
            showNotification('❌ ' + (result.msg || 'Error al actualizar perfil'), true);
        }
    } catch (error) {
        showNotification('❌ Error al conectar con el servidor', true);
    }
}

async function guardarDireccion(e) {
    e.preventDefault();
    const user = getUser();
    if (!user) { showNotification('❌ Error de sesión', true); return; }
    const direccion = document.getElementById('inputDireccion').value;
    const ciudadId = document.getElementById('inputCiudad').value;
    const postal = document.getElementById('inputPostal').value;
    if (!ciudadId) { showNotification('❌ Debes seleccionar una ciudad', true); return; }
    try {
        const response = await secureFetch(`${API_BASE_URL}/user_actions.php`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({ action: 'update_address', uid: user.id, direccion, ciudad_id: parseInt(ciudadId), postal })
        });
        const result = await response.json();
        if (result.ok) {
            const selectCiudad = document.getElementById('inputCiudad');
            const ciudadNombre = selectCiudad.options[selectCiudad.selectedIndex].text;
            document.getElementById('direccionPrincipal').textContent = `${direccion}, ${ciudadNombre}`;
            showNotification('✅ Dirección guardada correctamente');
            setTimeout(() => showSection('inicio'), 1500);
        } else {
            showNotification('❌ ' + (result.msg || 'Error al guardar dirección'), true);
        }
    } catch (error) {
        showNotification('❌ Error al conectar con el servidor', true);
    }
}

function seleccionarServicio(nombreServicio, idServicio, precio, duracion) {
    document.getElementById('servicioSeleccionado').value = nombreServicio;
    document.getElementById('servicioSeleccionadoId').value = idServicio;

    // Mostrar resumen del servicio en el formulario
    const infoResumen = document.getElementById('infoResumenServicio');
    if (infoResumen) {
        infoResumen.innerHTML = `
            <div style="background: rgba(184, 134, 11, 0.1); padding: 15px; border-radius: 8px; margin-bottom: 20px; border-left: 4px solid var(--primary-color);">
                <p style="margin: 0; color: var(--secondary-color); font-weight: 600;">
                    <i class="fas fa-tag"></i> Costo Base: <span style="color: var(--primary-dark);">${typeof formatPrice === 'function' ? formatPrice(parseFloat(precio)) : '$' + parseFloat(precio).toLocaleString()}</span>
                </p>
                <p style="margin: 5px 0 0 0; color: var(--secondary-color); font-weight: 600;">
                    <i class="fas fa-clock"></i> Tiempo Estm.: <span style="color: var(--primary-dark);">${duracion}</span>
                </p>
            </div>
        `;
    }

    const form = document.getElementById('formSolicitudServicio');
    if (form) {
        form.classList.remove('hidden');
        form.scrollIntoView({ behavior: 'smooth', block: 'center' });
    }
}

function cancelarSolicitud() {
    const form = document.getElementById('formSolicitudServicio');
    if (form) {
        form.reset();
        form.classList.add('hidden');
    }
    window.scrollTo({ top: 0, behavior: 'smooth' });
}

const formSolicitud = document.getElementById('formSolicitudServicio');
if (formSolicitud) {
    formSolicitud.addEventListener('submit', async function (e) {
        e.preventDefault();
        const user = getUser();
        if (!user) { showNotification('❌ Error de sesión', true); return; }
        const idServicio = document.getElementById('servicioSeleccionadoId').value;
        const nombreServicio = document.getElementById('servicioSeleccionado').value;
        const fechaPreferida = document.getElementById('fechaPreferida').value;
        const prioridad = document.getElementById('prioridad').value;
        const notas = document.getElementById('notasServicio').value;
        try {
            const response = await secureFetch(`${API_BASE_URL}/citas.php`, {
                method: 'POST',
                headers: { 'Content-Type': 'application/json' },
                body: JSON.stringify({ p_id_servicio: idServicio, p_fecha_pref: fechaPreferida, p_prioridad: prioridad, p_notas: notas })
            });
            const result = await response.json();
            if (result.ok) {
                showNotification(`✅ Solicitud enviada correctamente`);
                this.reset();
                this.classList.add('hidden');
                // Recargar citas para actualizar conteo y tabla inmediatamente
                await cargarCitas();
                setTimeout(() => showSection('inicio'), 2000);
            } else {
                showNotification('❌ ' + result.msg, true);
            }
        } catch (error) {
            showNotification('❌ Error al conectar con el servidor', true);
        }
    });
}


async function enviarResena(e) {
    e.preventDefault();

    // 1. Verificar sesión de usuario
    const user = getUser();
    if (!user) {
        showNotification('❌ Debes iniciar sesión para enviar una reseña', true);
        return;
    }

    // 2. Obtener calificación seleccionada
    const ratingInputs = document.getElementsByName('rating');
    let calificacion = 0;
    for (const input of ratingInputs) {
        if (input.checked) {
            calificacion = parseInt(input.value);
            break;
        }
    }

    if (!calificacion || calificacion < 1 || calificacion > 5) {
        showNotification('❌ Por favor selecciona una calificación de 1 a 5 estrellas', true);
        return;
    }

    // 3. Obtener comentario
    const comentario = document.getElementById('resenaTexto')?.value?.trim();
    if (!comentario) {
        showNotification('❌ Por favor escribe un comentario', true);
        return;
    }

    // 4. Preparar datos para enviar
    const payload = {
        calificacion: calificacion,
        comentario: comentario
    };

    try {
        // 5. Enviar petición
        const response = await secureFetch(`${API_BASE_URL}/resenas.php`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify(payload)
        });

        // 6. Procesar respuesta
        const data = await response.json();

        if (data.ok) {
            showNotification('✅ ' + (data.msg || 'Reseña enviada correctamente'));
            e.target.reset();
            setTimeout(() => showSection('inicio'), 1500);
        } else {
            showNotification('❌ ' + (data.msg || 'Error al enviar la reseña'), true);
        }
    } catch (error) {
        console.error('Error en enviarResena:', error);
        showNotification('❌ Error de conexión: ' + error.message, true);
    }
}

async function cargarServiciosPanel() {
    const servicesGrid = document.getElementById('user-services-grid');
    if (!servicesGrid) return;
    try {
        const res = await secureFetch(`${API_BASE_URL}/servicios.php`);
        const data = await res.json();
        if (data.ok) {
            servicesGrid.innerHTML = data.servicios.map(s => `
                <div class="service-card">
                    <div class="service-prime-tag">Premium</div>
                    <h3>${s.nom_servicio}</h3>
                    <p class="service-description">${s.descripcion}</p>
                    <div class="service-meta">
                        <span><i class="fas fa-clock"></i> ${s.duracion_estimada}</span>
                        <span><i class="fas fa-tag"></i> ${typeof formatPrice === 'function' ? formatPrice(parseFloat(s.precio_servicio)) : '$' + parseFloat(s.precio_servicio).toLocaleString()}</span>
                    </div>
                    <button class="button button-primary btn-solicitar-servicio" 
                        data-nombre="${s.nom_servicio}" 
                        data-id="${s.id_servicio}" 
                        data-precio="${s.precio_servicio}" 
                        data-duracion="${s.duracion_estimada}">
                        Solicitar Servicio
                    </button>
                </div>
            `).join('');
        }
    } catch (e) { }
}
