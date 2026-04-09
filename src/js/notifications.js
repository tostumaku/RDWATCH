/**
 * RD Watch - Sistema de Notificaciones Toast Profesional
 */
window.showNotification = function (msg, type = 'success') {
    let notif = document.getElementById('notification');

    // Si no existe, crearlo dinámicamente
    if (!notif) {
        notif = document.createElement('div');
        notif.id = 'notification';
        notif.className = 'notification';
        document.body.appendChild(notif);
    }

    const isError = type === 'error' || msg.toLowerCase().includes('error') || msg.includes('⚠️') || msg.includes('❌');

    notif.textContent = msg;
    notif.className = 'notification';
    notif.classList.add(isError ? 'error' : 'success');

    // Forzado de reflow para reiniciar animación si ya estaba mostrándose
    notif.classList.remove('show');
    void notif.offsetWidth;

    notif.classList.add('show');

    // Auto-ocultar tras 4 segundos
    if (window.notifTimeout) clearTimeout(window.notifTimeout);
    window.notifTimeout = setTimeout(() => {
        notif.classList.remove('show');
    }, 4000);
};

/**
 * RD Watch - Modal de Confirmación Premium
 * Reemplaza al confirm() nativo del navegador.
 * Uso: const ok = await showConfirm('¿Deseas cerrar sesión?');
 *      if (!ok) return;
 */
window.showConfirm = function (message, { confirmText = 'Confirmar', cancelText = 'Cancelar', danger = false } = {}) {
    return new Promise((resolve) => {

        // ── Inyectar estilos si no existen ──────────────────────────────
        if (!document.getElementById('rdw-confirm-styles')) {
            const style = document.createElement('style');
            style.id = 'rdw-confirm-styles';
            style.textContent = `
                .rdw-confirm-backdrop {
                    position: fixed; inset: 0;
                    background: rgba(0, 0, 0, 0.6);
                    backdrop-filter: blur(4px);
                    z-index: 99999;
                    display: flex; align-items: center; justify-content: center;
                    opacity: 0; transition: opacity 0.22s ease;
                }
                .rdw-confirm-backdrop.rdw-visible { opacity: 1; }

                .rdw-confirm-box {
                    background: #ffffff;
                    border-radius: 10px;
                    padding: 32px 28px 24px;
                    max-width: 420px; width: 90%;
                    box-shadow: 0 24px 60px rgba(0,0,0,0.25);
                    border-top: 4px solid #AF944F;
                    font-family: 'Montserrat', sans-serif;
                    transform: translateY(16px) scale(0.97);
                    transition: transform 0.22s cubic-bezier(0.4, 0, 0.2, 1);
                    position: relative;
                }
                .rdw-confirm-backdrop.rdw-visible .rdw-confirm-box {
                    transform: translateY(0) scale(1);
                }

                .rdw-confirm-icon {
                    width: 52px; height: 52px; border-radius: 50%;
                    display: flex; align-items: center; justify-content: center;
                    margin: 0 auto 16px;
                    font-size: 1.3rem;
                }
                .rdw-confirm-icon.rdw-danger { background: rgba(146,0,10,0.1); color: #92000A; }
                .rdw-confirm-icon.rdw-warn    { background: rgba(175,148,79,0.15); color: #8E783F; }

                .rdw-confirm-title {
                    font-family: 'Playfair Display', serif;
                    font-size: 1.1rem; font-weight: 700;
                    color: #0D0D0D; text-align: center;
                    margin-bottom: 10px; line-height: 1.4;
                }
                .rdw-confirm-actions {
                    display: flex; gap: 10px; margin-top: 24px; justify-content: flex-end;
                }
                .rdw-confirm-btn {
                    padding: 10px 22px; border-radius: 4px; border: none;
                    font-family: 'Montserrat', sans-serif; font-size: 0.8rem;
                    font-weight: 600; text-transform: uppercase; letter-spacing: 0.12em;
                    cursor: pointer; transition: all 0.2s ease;
                }
                .rdw-confirm-btn.rdw-cancel {
                    background: #f2f2f2; color: #333333; border: 1px solid #ddd;
                }
                .rdw-confirm-btn.rdw-cancel:hover { background: #e5e5e5; }

                .rdw-confirm-btn.rdw-ok {
                    background: #AF944F; color: #0D0D0D;
                    box-shadow: 0 4px 14px rgba(175,148,79,0.3);
                }
                .rdw-confirm-btn.rdw-ok:hover {
                    background: #D4BD86;
                    box-shadow: 0 6px 20px rgba(175,148,79,0.45);
                    transform: translateY(-1px);
                }
                .rdw-confirm-btn.rdw-ok.rdw-danger-ok {
                    background: #92000A; color: #fff;
                    box-shadow: 0 4px 14px rgba(146,0,10,0.3);
                }
                .rdw-confirm-btn.rdw-ok.rdw-danger-ok:hover {
                    background: #b50010;
                    box-shadow: 0 6px 20px rgba(146,0,10,0.45);
                }
            `;
            document.head.appendChild(style);
        }

        // ── Construir el modal ───────────────────────────────────────────
        const backdrop = document.createElement('div');
        backdrop.className = 'rdw-confirm-backdrop';

        const iconClass = danger ? 'rdw-danger' : 'rdw-warn';
        const iconGlyph = danger ? 'fa-trash-alt' : 'fa-exclamation-triangle';

        backdrop.innerHTML = `
            <div class="rdw-confirm-box" role="dialog" aria-modal="true" aria-label="Confirmación">
                <div class="rdw-confirm-icon ${iconClass}">
                    <i class="fas ${iconGlyph}"></i>
                </div>
                <p class="rdw-confirm-title">${message}</p>
                <div class="rdw-confirm-actions">
                    <button class="rdw-confirm-btn rdw-cancel" id="rdwCancelBtn">${cancelText}</button>
                    <button class="rdw-confirm-btn rdw-ok ${danger ? 'rdw-danger-ok' : ''}" id="rdwOkBtn">${confirmText}</button>
                </div>
            </div>
        `;

        document.body.appendChild(backdrop);

        // Activar animación de entrada
        requestAnimationFrame(() => {
            requestAnimationFrame(() => backdrop.classList.add('rdw-visible'));
        });

        // ── Helpers de cierre ────────────────────────────────────────────
        function close(result) {
            backdrop.classList.remove('rdw-visible');
            setTimeout(() => {
                backdrop.remove();
                document.removeEventListener('keydown', onKey);
            }, 240);
            resolve(result);
        }

        // ── Eventos ──────────────────────────────────────────────────────
        backdrop.getElementById = null; // IE safety
        const okBtn     = backdrop.querySelector('#rdwOkBtn');
        const cancelBtn = backdrop.querySelector('#rdwCancelBtn');

        okBtn.addEventListener('click',     () => close(true));
        cancelBtn.addEventListener('click', () => close(false));

        // Clic fuera del modal = cancelar
        backdrop.addEventListener('click', (e) => {
            if (e.target === backdrop) close(false);
        });

        // Teclado: Enter = confirmar, Escape = cancelar
        function onKey(e) {
            if (e.key === 'Enter')  { e.preventDefault(); close(true); }
            if (e.key === 'Escape') { e.preventDefault(); close(false); }
        }
        document.addEventListener('keydown', onKey);

        // Foco en el botón de confirmar
        setTimeout(() => okBtn.focus(), 260);
    });
};
