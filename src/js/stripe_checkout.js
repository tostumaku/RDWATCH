/**
 * RD Watch - Sistema de Gestión de Relojería
 * Integración de Stripe para Pagos Seguros
 */

let stripe = null;
let elements = null;
let card = null;

/**
 * Inicializa Stripe con la clave pública obtenida del servidor
 */
async function initStripe() {
    try {
        const res = await secureFetch(`${API_BASE}/stripe_config.php`);
        const data = await res.json();

        if (data.ok && data.publicKey) {
            stripe = Stripe(data.publicKey);
        } else {
            console.error('No se pudo cargar la configuración de Stripe:', data.msg);
        }
    } catch (error) {
        console.error('Error inicializando Stripe:', error);
    }
}

/**
 * Monta el elemento de tarjeta de Stripe en el DOM
 */
function mountStripeCard(containerId) {
    if (!stripe) return;

    elements = stripe.elements();
    const style = {
        base: {
            color: "#fff",
            fontFamily: '"Outfit", sans-serif',
            fontSmoothing: "antialiased",
            fontSize: "16px",
            "::placeholder": {
                color: "#aab7c4"
            }
        },
        invalid: {
            color: "#fa755a",
            iconColor: "#fa755a"
        }
    };

    card = elements.create("card", { style: style });
    card.mount(`#${containerId}`);

    card.on('change', ({ error }) => {
        const displayError = document.getElementById('card-errors');
        if (error) {
            displayError.textContent = error.message;
        } else {
            displayError.textContent = '';
        }
    });
}

/**
 * Maneja el proceso de pago con Stripe
 * @param {Object} orderData - Datos del pedido (monto, etc)
 */
async function handleStripePayment(orderData) {
    if (!stripe || !card) {
        return { ok: false, msg: 'Sistema de pago no inicializado' };
    }

    try {
        // 1. Crear PaymentIntent en el backend
        // Montos reales deberían calcularse en el backend basándose en el carrito
        const res = await secureFetch(`${API_BASE}/create_payment.php`, {
            method: 'POST',
            headers: { 'Content-Type': 'application/json' },
            body: JSON.stringify({
                amount: orderData.amount, // En centavos
                currency: 'cop'
            })
        });

        const data = await res.json();
        if (!data.ok) throw new Error(data.msg || 'Error al iniciar pago');

        const clientSecret = data.clientSecret;

        // 2. Confirmar el pago con Stripe
        const result = await stripe.confirmCardPayment(clientSecret, {
            payment_method: {
                card: card,
                billing_details: {
                    name: orderData.customerName || 'Cliente RD Watch'
                }
            }
        });

        if (result.error) {
            return { ok: false, msg: result.error.message };
        } else if (result.paymentIntent.status === 'succeeded') {
            return { ok: true, paymentIntent: result.paymentIntent };
        }

    } catch (error) {
        console.error("Error en pago Stripe:", error);
        return { ok: false, msg: error.message };
    }

    return { ok: false, msg: 'Error desconocido en el proceso de pago' };
}

// Inicializar al cargar el script si existe Stripe
if (typeof Stripe !== 'undefined') {
    initStripe();
}
