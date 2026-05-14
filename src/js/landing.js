/**
 * ARCHIVO: js/landing.js
 * MÓDULO: Componentes de la Página de Inicio (Landing Page)
 * Dependencias: config.js, security.js, notifications.js, utils.js (formatPrice)
 *
 * Contenido:
 *   - Estadísticas animadas (loadStats, animateValue)
 *   - Carga dinámica de reseñas (loadTestimonials)
 *   - Carga dinámica de servicios en carrusel (loadServices, initServicesCarousel)
 *   - Carrusel de galería (initGalleryCarousel)
 *   - Formulario de contacto (handleContactForm, setupContactValidation)
 */

// =========================================================
// 1. ESTADÍSTICAS ANIMADAS
// =========================================================

async function loadStats() {
    try {
        const res = await secureFetch(`${API_BASE}/stats_public.php`);
        const data = await res.json();

        if (data.ok && data.public) {
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
            animateValue("stat-repaired", 0, 0, 2000);
            animateValue("stat-satisfaction", 0, 98, 2000);
        }
    } catch (error) {
        console.error('Error loading stats:', error);
        animateValue("stat-years", 0, 50, 2000);
        animateValue("stat-repaired", 0, 0, 2000);
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
// 2. RESEÑAS (TESTIMONIOS DINÁMICOS)
// =========================================================

async function loadTestimonials() {
    const sliderContainer = document.querySelector('.reviews-slider');
    if (!sliderContainer) return;

    try {
        const res = await secureFetch(`${API_BASE}/resenas.php`);
        const data = await res.json();

        if (data.ok && data.resenas.length > 0) {
            sliderContainer.innerHTML = '';

            data.resenas.forEach(review => {
                const rating = parseFloat(review.calificacion);
                let starsHtml = '';
                for (let i = 1; i <= 5; i++) {
                    if (rating >= i) {
                        starsHtml += '<i class="fas fa-star"></i>';
                    } else if (rating >= i - 0.5) {
                        starsHtml += '<i class="fas fa-star-half-alt"></i>';
                    } else {
                        starsHtml += '<i class="far fa-star"></i>';
                    }
                }

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

// =========================================================
// 3. SERVICIOS EN CARRUSEL
// =========================================================

async function loadServices() {
    const servicesContainer = document.querySelector('#services-section .container');
    const originalGrid = document.getElementById('public-services-grid');

    if (!servicesContainer) return;

    try {
        const res = await secureFetch(`${API_BASE_SHOP}/servicios.php`);
        const data = await res.json();

        if (data.ok && data.servicios.length > 0) {
            if (originalGrid) originalGrid.remove();

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

    const getCardWidth = () => {
        const card = track.querySelector('.service-card');
        if (!card) return 320;
        const style = window.getComputedStyle(track);
        const gap = parseFloat(style.gap) || 20;
        return card.offsetWidth + gap;
    };

    nextBtn.addEventListener('click', () => {
        const cardWidth = getCardWidth();
        const maxScroll = track.scrollWidth - track.clientWidth;
        let targetScroll = track.scrollLeft + cardWidth;
        if (targetScroll >= maxScroll - 10) targetScroll = maxScroll;
        track.scrollTo({ top: 0, left: targetScroll, behavior: 'smooth' });
    });

    prevBtn.addEventListener('click', () => {
        const cardWidth = getCardWidth();
        let targetScroll = track.scrollLeft - cardWidth;
        if (targetScroll < 0) targetScroll = 0;
        track.scrollTo({ top: 0, left: targetScroll, behavior: 'smooth' });
    });
}

// =========================================================
// 4. CARRUSEL DE GALERÍA
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

    const section = document.getElementById('gallery-section');
    if (section) observer.observe(section);
}

// =========================================================
// 5. FORMULARIO DE CONTACTO
// =========================================================

async function handleContactForm(e) {
    e.preventDefault();

    const form = e.target;
    const submitBtn = form.querySelector('button[type="submit"]');
    const btnText = submitBtn.querySelector('.btn-text');
    const btnLoader = submitBtn.querySelector('.btn-loader');

    const nombre = document.getElementById('contact-name').value.trim();
    const email = document.getElementById('contact-email').value.trim();
    const telefono = document.getElementById('contact-phone').value.trim();
    const mensaje = document.getElementById('contact-message').value.trim();

    if (!nombre || !email || !mensaje) {
        showNotification('❌ Por favor completa todos los campos obligatorios', true);
        return;
    }

    if (!validateName(nombre)) {
        showNotification('❌ El nombre solo debe contener letras y espacios', true);
        document.getElementById('contact-name').focus();
        return;
    }

    if (telefono && !/^\d{10}$/.test(telefono)) {
        showNotification('❌ El teléfono debe tener 10 dígitos numéricos', true);
        document.getElementById('contact-phone').focus();
        return;
    }

    if (btnText) btnText.style.display = 'none';
    if (btnLoader) btnLoader.style.display = 'inline-block';
    submitBtn.disabled = true;

    try {
        const payload = { nombre, email, telefono, mensaje };

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
        if (btnText) btnText.style.display = 'inline-block';
        if (btnLoader) btnLoader.style.display = 'none';
        submitBtn.disabled = false;
    }
}

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

// =========================================================
// 6. INICIALIZACIÓN
// =========================================================

document.addEventListener('DOMContentLoaded', () => {
    loadStats();
    loadTestimonials();
    loadServices();
    initGalleryCarousel();

    // Conectar formulario de contacto
    const contactForm = document.getElementById('contactForm');
    if (contactForm) {
        contactForm.addEventListener('submit', handleContactForm);
    }

    setupContactValidation();
});
