-- ============================================================
-- MÓDULO: NÚCLEO E-COMMERCE (ecommerce_core.sql)
-- ============================================================o
-- Fase        : 3 de 5 — Transacciones y Compras
-- ============================================================
--
-- ╔══════════════════════════════════════════════════════════╗
-- ║  PRINCIPIO FUNDAMENTAL: OCULTACIÓN TOTAL               ║
-- ║  PHP NUNCA ve nombres de tablas ni columnas.            ║
-- ║  Todas las funciones retornan JSON puro.                ║
-- ║  El checkout es UNA SOLA función atómica.               ║
-- ╚══════════════════════════════════════════════════════════╝
--
-- FUNCIONES EN ESTE MÓDULO (15 total):
-- ────────────────────────────────────
-- CARRITO (6):
--   1. fn_cart_get_or_create     → Obtener/crear carrito activo
--   2. fn_cart_get_items         → Listar ítems con precios actuales
--   3. fn_cart_add_item          → Agregar producto (o incrementar cantidad)
--   4. fn_cart_update_qty        → Cambiar cantidad de un ítem
--   5. fn_cart_remove_item       → Quitar un producto específico
--   6. fn_cart_clear             → Vaciar todo el carrito
-- CHECKOUT (1):
--   7. fn_checkout_process       → MEGA-FUNCIÓN ATÓMICA: carrito → orden
-- PEDIDOS (2):
--   8. fn_orders_list            → Listar pedidos con filtros dinámicos
--   9. fn_orders_update_status   → Actualizar estado logístico
-- CITAS/RESERVAS (4):
--  10. fn_citas_list_admin       → Listar citas (vista administrador)
--  11. fn_citas_list_cliente     → Listar citas (vista cliente)
--  12. fn_citas_create           → Crear nueva reserva de servicio
--  13. fn_citas_update_status    → Actualizar estado de reserva
-- CONTACTO (2):
--  14. fn_contacto_check_dup     → Anti-duplicado de mensajes
--  15. fn_contacto_create        → Crear reserva desde landing page
--
-- TABLAS QUE ESTE MÓDULO TOCA (pero PHP no lo sabe):
-- ────────────────────────────────────
-- tab_Carrito          → Estado del carrito (activo/convertido)
-- tab_Carrito_Detalle  → Ítems dentro del carrito
-- tab_Productos        → Stock y precios
-- tab_Orden            → Cabecera de órdenes de compra
-- tab_Detalle_Orden    → Líneas de cada orden
-- tab_Facturas         → Facturación legal
-- tab_Detalle_Factura  → Líneas de factura
-- tab_Envios           → Logística de envío
-- tab_Pagos            → Comprobantes de pago (ruta en disco)
-- tab_Direcciones_Envio → Direcciones del cliente
-- tab_Ciudades         → Catálogo de ciudades
-- tab_Reservas         → Citas técnicas del taller
-- tab_Servicios        → Catálogo de servicios
-- tab_Usuarios         → Datos de clientes (JOINs)
-- ============================================================


-- ██████████████████████████████████████████████████████████
-- ██  SECCIÓN 1: CARRITO DE COMPRAS                       ██
-- ██████████████████████████████████████████████████████████
--
-- El carrito persiste en la BD (no en localStorage).
-- Cada usuario tiene como máximo UN carrito 'activo'.
-- Cuando se hace checkout, el carrito pasa a 'convertido_a_orden'.
--
-- Ciclo de vida:
--   [no existe] → fn_cart_get_or_create → [activo]
--   [activo] → fn_cart_add_item / update / remove → [activo]
--   [activo] → fn_checkout_process → [convertido_a_orden]


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 1: fn_cart_get_or_create                       ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Gestionar la sesión persistente del        ║
-- ║               carrito de compras del usuario.           ║
-- ║  Llamada PHP: SELECT fn_cart_get_or_create(user_id)     ║
-- ║  Retorna    : JSON {id_carrito: INTEGER, created: BOOL}  ║
-- ║                                                         ║
-- ║  FLUJO LÓGICO:                                          ║
-- ║  1. Búsqueda: Intenta localizar un carrito con estado    ║
-- ║     'activo' para el usuario logueado.                  ║
-- ║  2. Decisión:                                           ║
-- ║     - Si existe: Retorna el ID actual.                  ║
-- ║     - Si no: Genera un ID basado en Epoch (TIMESTAMP),  ║
-- ║       inserta el registro y marca created=TRUE.         ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_cart_get_or_create(
    p_user_id tab_Usuarios.id_usuario%TYPE  -- ID único del usuario autenticado
)
RETURNS JSON
AS $$
DECLARE
    v_cart_id tab_Carrito.id_carrito%TYPE;   -- Variable de captura de ID
    v_created BOOLEAN := FALSE; -- Flag de creación
BEGIN
    -- PASO 1: Consulta de estado actual.
    -- Filtramos estrictamente por 'activo' porque un usuario puede tener 
    -- carritos anteriores ya 'convertidos_a_orden'.
    SELECT c.id_carrito INTO v_cart_id
    FROM tab_Carrito c
    WHERE c.id_usuario = p_user_id
      AND c.estado_carrito = 'activo'
    LIMIT 1;

    -- PASO 2: Inicialización en caso de primer acceso.
    IF v_cart_id IS NULL THEN
        -- Generación manual de ID: Buscamos el máximo actual + 1.
        -- LOCK previene condición de carrera en generación concurrente de IDs.
        LOCK TABLE tab_Carrito IN EXCLUSIVE MODE;
        SELECT COALESCE(MAX(id_carrito), 0) + 1 INTO v_cart_id FROM tab_Carrito;
        
        INSERT INTO tab_Carrito (
            id_carrito, 
            id_usuario, 
            estado_carrito, 
            fec_insert, 
            usr_insert
        ) VALUES (
            v_cart_id, 
            p_user_id, 
            'activo', 
            NOW(), 
            'system_cart' -- Marca de origen automático
        );
        v_created := TRUE;
    END IF;

    -- Entregamos el objeto de control al backend PHP.
    RETURN json_build_object('id_carrito', v_cart_id, 'created', v_created);
END;
$$ LANGUAGE plpgsql;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 2: fn_cart_get_items                           ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Recuperar el listado de productos en el     ║
-- ║               carrito con datos actualizados de la BD.  ║
-- ║  Llamada PHP: SELECT fn_cart_get_items(cart_id)         ║
-- ║  Retorna    : JSON array [{prod_id, nom, precio...},...] ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Cliente abre la vista del carrito en el frontend.   ║
-- ║  2. PHP ejecuta SELECT fn_cart_get_items(cart_id).      ║
-- ║  3. JOIN con tab_Productos trae precios vigentes.       ║
-- ║  4. Retorna JSON array → PHP renderiza el carrito.      ║
-- ║                                                         ║
-- ║  CONCEPTO: PRICING DINÁMICO                             ║
-- ║  El JOIN con tab_Productos garantiza que el usuario vea  ║
-- ║  el precio oficial vigente, incluso si este cambió      ║
-- ║  desde que el producto se agregó al carrito.            ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_cart_get_items(
    p_cart_id tab_Carrito.id_carrito%TYPE  -- Localizador único del carrito
)
RETURNS JSON
AS $$
DECLARE
    v_result JSON; -- Buffer para agrupar ítems
BEGIN
    -- Captura estructurada de filas en un array JSON.
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_result FROM (
        SELECT
            d.id_producto,     -- Clave del reloj
            p.nom_producto,    -- Etiqueta comercial
            p.precio,          -- Valor de venta actual (NUMERIC)
            p.url_imagen,      -- Asset visual para miniatura en carrito
            p.stock,           -- Cantidad en bodega (para alertas de falta de stock)
            d.cantidad         -- Unidades reservadas por el cliente
        FROM tab_Carrito_Detalle d
        JOIN tab_Productos p ON d.id_producto = p.id_producto -- Enlace físico obligatorio
        WHERE d.id_carrito = p_cart_id
    ) t;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE; -- Función estable optimizada para lectura


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 3: fn_cart_add_item                            ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Integrar (UPSERT) un producto al carrito   ║
-- ║               del usuario de forma transparente.        ║
-- ║  Llamada PHP: SELECT fn_cart_add_item(cart, prod, qty)  ║
-- ║  Retorna    : JSON {ok: true, msg: text}                ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Cliente pulsa "Agregar al carrito" en el catálogo.  ║
-- ║  2. PHP ejecuta fn_cart_add_item(cart, prod, qty).      ║
-- ║  3. La función busca si el producto ya existe.          ║
-- ║  4. Si ya existe → suma cantidad. Si no → INSERT nuevo. ║
-- ║  5. Retorna {ok, msg} → PHP confirma al frontend.       ║
-- ║                                                         ║
-- ║  INTELIGENCIA DE NEGOCIO:                               ║
-- ║  Detecta si el ítem ya existe. Si afirmativo, aplica    ║
-- ║  una suma aritmética a la cantidad previa. De lo        ║
-- ║  contrario, crea una nueva línea de detalle.            ║
-- ╚══════════════════════════════════════════════════════════╝
DROP FUNCTION IF EXISTS fn_cart_add_item(bigint, bigint, integer);
DROP FUNCTION IF EXISTS fn_cart_add_item(integer, integer, integer);
CREATE OR REPLACE FUNCTION fn_cart_add_item(
    p_cart_id  tab_Carrito.id_carrito%TYPE,   -- Relación con tab_Carrito
    p_prod_id  tab_Productos.id_producto%TYPE,   -- Relación con tab_Productos
    p_qty      tab_Carrito_Detalle.cantidad%TYPE   -- Unidades a incorporar
)
RETURNS JSON
AS $$
DECLARE
    v_existing tab_Carrito_Detalle.cantidad%TYPE;  -- Buffer para cantidad previa
    v_det_id   tab_Carrito_Detalle.id_carrito_detalle%TYPE;   -- Generación de PK para detalle
BEGIN
    -- VERIFICACIÓN: ¿Existe el solapamiento en el carrito?
    SELECT d.cantidad INTO v_existing
    FROM tab_Carrito_Detalle d
    WHERE d.id_carrito = p_cart_id AND d.id_producto = p_prod_id;

    IF v_existing IS NOT NULL THEN
        -- OPERACIÓN 1: Actualización incremental.
        UPDATE tab_Carrito_Detalle
        SET cantidad = v_existing + p_qty, 
            fec_update = NOW() -- Marca de modificación
        WHERE id_carrito = p_cart_id AND id_producto = p_prod_id;
    ELSE
        -- OPERACIÓN 2: Nueva inserción.
        -- LOCK previene condición de carrera en generación concurrente de IDs.
        LOCK TABLE tab_Carrito_Detalle IN EXCLUSIVE MODE;
        SELECT COALESCE(MAX(id_carrito_detalle), 0) + 1 INTO v_det_id FROM tab_Carrito_Detalle;
        
        INSERT INTO tab_Carrito_Detalle (
            id_carrito_detalle, 
            id_carrito, 
            id_producto, 
            cantidad, 
            fec_insert, 
            usr_insert
        ) VALUES (
            v_det_id, 
            p_cart_id, 
            p_prod_id, 
            p_qty, 
            NOW(), 
            'user_add_action' -- Auditoría del origen de la acción
        );
    END IF;

    RETURN json_build_object('ok', true, 'msg', 'El producto ha sido incorporado a su carrito de compras.');
END;
$$ LANGUAGE plpgsql;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 4: fn_cart_update_qty                          ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Sobrescribir la cantidad de un ítem ya      ║
-- ║               existente en el carrito de compras.       ║
-- ║  Llamada PHP: SELECT fn_cart_update_qty(123, 45, 5)     ║
-- ║  Retorna    : JSON {ok: true, msg: text}                ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Cliente ajusta cantidad en la vista del carrito.    ║
-- ║  2. PHP ejecuta fn_cart_update_qty(cart, prod, qty).    ║
-- ║  3. UPDATE focalizado por carrito+producto.             ║
-- ║  4. Retorna {ok, msg} → PHP refresca la vista.          ║
-- ╚══════════════════════════════════════════════════════════╝
DROP FUNCTION IF EXISTS fn_cart_update_qty(bigint, bigint, integer);
DROP FUNCTION IF EXISTS fn_cart_update_qty(integer, integer, integer);
CREATE OR REPLACE FUNCTION fn_cart_update_qty(
    p_cart_id tab_Carrito.id_carrito%TYPE,  -- Referencia al carrito activo
    p_prod_id tab_Productos.id_producto%TYPE,  -- Referencia al producto
    p_qty     tab_Carrito_Detalle.cantidad%TYPE  -- Nueva cantidad absoluta
)
RETURNS JSON
AS $$
BEGIN
    -- DML focalizado: Reemplaza la cantidad anterior por la nueva.
    UPDATE tab_Carrito_Detalle
    SET cantidad = p_qty, 
        fec_update = NOW()
    WHERE id_carrito = p_cart_id AND id_producto = p_prod_id;

    RETURN json_build_object('ok', true, 'msg', 'La cantidad del producto ha sido actualizada.');
END;
$$ LANGUAGE plpgsql;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 5: fn_cart_remove_item                         ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Eliminar un producto específico del       ║
-- ║               carrito (extracción quirúrgica).          ║
-- ║  Llamada PHP: SELECT fn_cart_remove_item(123, 45)       ║
-- ║  Retorna    : JSON {ok: true, msg: text}                ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Cliente pulsa "Quitar" en un ítem del carrito.       ║
-- ║  2. PHP ejecuta fn_cart_remove_item(cart, prod).        ║
-- ║  3. DELETE físico de la línea de detalle.               ║
-- ║  4. Retorna {ok, msg} → PHP refresca la vista.          ║
-- ╚══════════════════════════════════════════════════════════╝
DROP FUNCTION IF EXISTS fn_cart_remove_item(bigint, bigint);
DROP FUNCTION IF EXISTS fn_cart_remove_item(integer, integer);
CREATE OR REPLACE FUNCTION fn_cart_remove_item(
    p_cart_id tab_Carrito.id_carrito%TYPE, -- Localizador de la sesión
    p_prod_id tab_Productos.id_producto%TYPE  -- ID del producto a retirar
)
RETURNS JSON
AS $$
BEGIN
    -- Purga física de la línea de detalle.
    DELETE FROM tab_Carrito_Detalle
    WHERE id_carrito = p_cart_id AND id_producto = p_prod_id;

    RETURN json_build_object('ok', true, 'msg', 'El producto ha sido removido de su selección.');
END;
$$ LANGUAGE plpgsql;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 6: fn_cart_clear                               ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Resetear el carrito activo, eliminando      ║
-- ║               todas las líneas de detalle.              ║
-- ║  Llamada PHP: SELECT fn_cart_clear(123)                 ║
-- ║  Retorna    : JSON {ok: true, msg: text}                ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Cliente pulsa "Vaciar carrito" en el frontend.      ║
-- ║  2. PHP ejecuta SELECT fn_cart_clear(cart_id).          ║
-- ║  3. DELETE masivo de tab_Carrito_Detalle.                ║
-- ║  4. Retorna {ok, msg} → PHP refresca la vista vacía.    ║
-- ╚══════════════════════════════════════════════════════════╝
DROP FUNCTION IF EXISTS fn_cart_clear(bigint);
DROP FUNCTION IF EXISTS fn_cart_clear(integer);
CREATE OR REPLACE FUNCTION fn_cart_clear(
    p_cart_id tab_Carrito.id_carrito%TYPE -- ID del carrito a vaciar
)
RETURNS JSON
AS $$
BEGIN
    -- Limpieza masiva de dependencias del carrito.
    DELETE FROM tab_Carrito_Detalle WHERE id_carrito = p_cart_id;

    RETURN json_build_object('ok', true, 'msg', 'Su carrito ahora se encuentra vacío.');
END;
$$ LANGUAGE plpgsql;


-- ██████████████████████████████████████████████████████████
-- ██  SECCIÓN 2: CHECKOUT (La función más crítica)        ██
-- ██████████████████████████████████████████████████████████
--
-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 7: fn_checkout_process                         ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  MEGA-FUNCIÓN ATÓMICA: Convierte un carrito en una     ║
-- ║  orden de compra completa.                              ║
-- ║                                                         ║
-- ║  ¿Por qué UNA SOLA función?                            ║
-- ║  Porque el checkout involucra 6+ tablas que DEBEN       ║
-- ║  modificarse juntas o no modificarse en absoluto.       ║
-- ║  Si falla cualquier paso, NADA se guarda.               ║
-- ║  PostgreSQL garantiza esto con la transacción implícita.║
-- ║                                                         ║
-- ║  10 PASOS INTERNOS:                                     ║
-- ║  1. Obtener carrito activo del usuario                  ║
-- ║  2. Leer ítems con precios y stock actuales             ║
-- ║  3. Validar stock de CADA producto                      ║
-- ║  4. Crear orden (cabecera)                              ║
-- ║  5. Crear factura                                       ║
-- ║  6. Crear detalles de orden + factura + descontar stock ║
-- ║  7. Gestionar dirección de envío                        ║
-- ║  8. Crear registro de envío                             ║
-- ║  9. Crear registro de pago (sin comprobante binario)    ║
-- ║ 10. Limpiar carrito y marcarlo como convertido          ║
-- ║                                                         ║
-- ║  NOTA SOBRE EL COMPROBANTE:                             ║
-- ║  El archivo binario (BYTEA) se inserta APARTE desde PHP ║
-- ║  porque PostgreSQL no puede recibir BYTEA como param    ║
-- ║  dentro de una función fácilmente. PHP actualiza el     ║
-- ║  registro de pago con el comprobante después de esta    ║
-- ║  función.                                               ║
-- ╚══════════════════════════════════════════════════════════╝
-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 7: fn_checkout_process                         ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Orquestar la conversión de un carrito en    ║
-- ║               una Orden de Compra formal.               ║
-- ║  Llamada PHP: SELECT fn_checkout_process(...)           ║
-- ║  Retorna    : JSON {ok, msg, order_id, payment_id}       ║
-- ║                                                         ║
-- ║  FLUJO DE TRABAJO ATÓMICO:                              ║
-- ║  1. Captura del ID del carrito activo.                  ║
-- ║  2. Validación reactiva de Stock para cada ítem.        ║
-- ║  3. Cálculo de montos y totales vigentes.               ║
-- ║  4. Generación paralela de Orden, Factura y Envío.      ║
-- ║  5. Ajuste de Inventario (UPDATE Stock).                ║
-- ║  6. Clausura del carrito (Lógica de conversión).        ║
-- ╚══════════════════════════════════════════════════════════╝
DROP FUNCTION IF EXISTS fn_checkout_process(integer, text, text, text);
DROP FUNCTION IF EXISTS fn_checkout_process(bigint, text, text, text);
CREATE OR REPLACE FUNCTION fn_checkout_process(
    p_user_id    tab_Usuarios.id_usuario%TYPE,   -- ID del comprador
    p_direccion  tab_Direcciones_Envio.direccion_completa%TYPE,     -- Domicilio de destino
    p_ciudad     tab_Ciudades.nombre_ciudad%TYPE,     -- Ciudad para logística local
    p_metodo     tab_Metodos_Pago.nombre_metodo%TYPE      -- Referencia al medio de pago
)
RETURNS JSON
AS $$
DECLARE
    v_cart_id     tab_Carrito.id_carrito%TYPE;     -- Localizador del carrito
    v_order_id    tab_Orden.id_orden%TYPE;     -- PK de la nueva Orden
    v_invoice_id  tab_Facturas.id_factura%TYPE;     -- PK de la nueva Factura
    v_shipping_id tab_Envios.id_envio%TYPE;     -- PK del proceso de Envío
    v_payment_id  tab_Pagos.id_pago%TYPE;     -- PK del registro de Pago
    v_addr_id     tab_Direcciones_Envio.id_direccion%TYPE;     -- ID de dirección (nueva o existente)
    v_city_id     tab_Ciudades.id_ciudad%TYPE;    -- ID de mapeo de ciudad
    v_total       tab_Orden.total_orden%TYPE := 0; -- Acumulador de precio final
    v_concepto    tab_Orden.concepto%TYPE;       -- Glosa descriptiva
    v_item        RECORD;     -- Cursor de ítems del carrito
    v_idx         INTEGER := 0; -- Iterador de líneas detalle
    v_subtotal    tab_Detalle_Factura.subtotal_linea%TYPE;    -- Cálculo temporal por línea
BEGIN
    -- PASO 1: Localización del recurso base.
    SELECT c.id_carrito INTO v_cart_id
    FROM tab_Carrito c
    WHERE c.id_usuario = p_user_id AND c.estado_carrito = 'activo'
    LIMIT 1;

    IF v_cart_id IS NULL THEN
        RETURN json_build_object('ok', false,
            'msg', 'Error de sesión: No se detectó un carrito pendiente de procesar.');
    END IF;

    -- PASO 1.1: Auto-completado de dirección y ciudad si vienen vacíos.
    -- Si el frontend no envía dirección, buscamos en la agenda del usuario.
    IF p_direccion IS NULL OR p_direccion = '' THEN
        SELECT de.direccion_completa, ci.nombre_ciudad INTO p_direccion, p_ciudad
        FROM tab_Direcciones_Envio de
        JOIN tab_Ciudades ci ON de.id_ciudad = ci.id_ciudad
        WHERE de.id_usuario = p_user_id
        ORDER BY de.es_predeterminada DESC, de.id_direccion DESC
        LIMIT 1;

        -- Si aún es NULL, intentamos del perfil maestro.
        p_direccion := COALESCE(p_direccion, (SELECT direccion_principal FROM tab_Usuarios WHERE id_usuario = p_user_id));
        p_ciudad := COALESCE(p_ciudad, 'Ciudad Metropolitana'); -- Fallback final
    END IF;

    -- Validación final: Si después de los intentos sigue sin haber dirección, error.
    IF p_direccion IS NULL OR p_direccion = '' THEN
        RETURN json_build_object('ok', false, 'msg', 'Requerimiento: Por favor, ingrese o seleccione una dirección de envío.');
    END IF;

    -- PASO 2-3: Auditoría de Disponibilidad y Costeo.
    -- Recorremos la selección del usuario para validar stock antes de comprometer la orden.
    FOR v_item IN
        SELECT d.id_producto, d.cantidad, p.precio, p.stock, p.nom_producto
        FROM tab_Carrito_Detalle d
        JOIN tab_Productos p ON d.id_producto = p.id_producto
        WHERE d.id_carrito = v_cart_id
    LOOP
        -- Validación crítica de existencias físicas.
        IF v_item.stock < v_item.cantidad THEN
            RETURN json_build_object('ok', false,
                'msg', 'Ruptura de Stock: Solo disponemos de ' || v_item.stock || ' unidades de ' || v_item.nom_producto);
        END IF;
        -- Cálculo incremental del total orden.
        v_total := v_total + (v_item.precio * v_item.cantidad);
    END LOOP;

    -- Barrera de seguridad para carritos inconsistentes.
    IF v_total = 0 THEN
        RETURN json_build_object('ok', false, 'msg', 'Inconsistencia: El monto total no puede ser cero.');
    END IF;

    -- PASO 4: Generación de Entidad Orden (Maestro).
    -- LOCK previene condición de carrera en generación concurrente de IDs.
    LOCK TABLE tab_Orden IN EXCLUSIVE MODE;
    SELECT COALESCE(MAX(id_orden), 0) + 1 INTO v_order_id FROM tab_Orden;
    v_concepto := LEFT('Relojería RD-Watch: Despacho a ' || p_direccion, 100);

    INSERT INTO tab_Orden (
        id_orden, id_usuario, fecha_orden, estado_orden, total_orden, concepto, fec_insert, usr_insert
    ) VALUES (
        v_order_id, p_user_id, NOW(), 'pendiente', v_total, v_concepto, NOW(), 'checkout_kernel'
    );

    -- PASO 5: Registro Contable (Facturación).
    -- LOCK previene condición de carrera en generación concurrente de IDs.
    LOCK TABLE tab_Facturas IN EXCLUSIVE MODE;
    SELECT COALESCE(MAX(id_factura), 0) + 1 INTO v_invoice_id FROM tab_Facturas;
    INSERT INTO tab_Facturas (
        id_factura, id_orden, id_usuario, fecha_emision, total_factura, estado_factura, fec_insert, usr_insert
    ) VALUES (
        v_invoice_id, v_order_id, p_user_id, NOW(), v_total, 'Emitida', NOW(), 'checkout_kernel'
    );

    -- PASO 6: Transferencia de Detalles y Ajuste de Inventario.
    FOR v_item IN
        SELECT d.id_producto, d.cantidad, p.precio
        FROM tab_Carrito_Detalle d
        JOIN tab_Productos p ON d.id_producto = p.id_producto
        WHERE d.id_carrito = v_cart_id
    LOOP
        v_idx := v_idx + 1;
        v_subtotal := v_item.cantidad * v_item.precio;

        -- Registro en Detalle de Orden (ID manual secuencial).
        -- LOCK previene condición de carrera en generación concurrente de IDs.
        LOCK TABLE tab_Detalle_Orden IN EXCLUSIVE MODE;
        INSERT INTO tab_Detalle_Orden (
            id_detalle_orden, id_orden, id_producto, cantidad, precio_unitario, fec_insert, usr_insert
        ) VALUES (
            (SELECT COALESCE(MAX(id_detalle_orden), 0) + 1 FROM tab_Detalle_Orden), 
            v_order_id, v_item.id_producto, v_item.cantidad, v_item.precio, NOW(), 'checkout_kernel'
        );

        -- Registro en Detalle de Factura (ID manual secuencial).
        -- LOCK previene condición de carrera en generación concurrente de IDs.
        LOCK TABLE tab_Detalle_Factura IN EXCLUSIVE MODE;
        INSERT INTO tab_Detalle_Factura (
            id_detalle_factura, id_factura, id_producto, cantidad, precio_unitario, subtotal_linea, fec_insert, usr_insert
        ) VALUES (
            (SELECT COALESCE(MAX(id_detalle_factura), 0) + 1 FROM tab_Detalle_Factura), 
            v_invoice_id, v_item.id_producto, v_item.cantidad, v_item.precio, v_subtotal, NOW(), 'checkout_kernel'
        );

        -- COMPROMISO DE STOCK: Reducción inmediata de unidades disponibles.
        UPDATE tab_Productos SET 
            stock = stock - v_item.cantidad, 
            fec_update = NOW(), 
            usr_update = 'checkout_engine'
        WHERE id_producto = v_item.id_producto;
    END LOOP;

    -- PASO 7: Registro Logístico de Domicilio.
    SELECT de.id_direccion INTO v_addr_id
    FROM tab_Direcciones_Envio de
    WHERE de.id_usuario = p_user_id AND de.direccion_completa = p_direccion
    LIMIT 1;

    IF v_addr_id IS NULL THEN
        -- Normalización de Ciudad y creación de nueva dirección (ID manual).
        -- LOCK previene condición de carrera en generación concurrente de IDs.
        LOCK TABLE tab_Direcciones_Envio IN EXCLUSIVE MODE;
        SELECT COALESCE(MAX(id_direccion), 0) + 1 INTO v_addr_id FROM tab_Direcciones_Envio;

        SELECT ci.id_ciudad INTO v_city_id
        FROM tab_Ciudades ci
        WHERE ci.nombre_ciudad ILIKE '%' || p_ciudad || '%'
        LIMIT 1;
        
        v_city_id := COALESCE(v_city_id, 1); -- Fallback a ciudad metropolitana

        INSERT INTO tab_Direcciones_Envio (
            id_direccion, id_usuario, direccion_completa, id_ciudad, codigo_postal, es_predeterminada, fec_insert, usr_insert
        ) VALUES (
            v_addr_id, p_user_id, p_direccion, v_city_id, '7600000', FALSE, NOW(), 'checkout_kernel'
        );
    END IF;

    -- PASO 8: Planificación de Despacho (Logística).
    -- LOCK previene condición de carrera en generación concurrente de IDs.
    LOCK TABLE tab_Envios IN EXCLUSIVE MODE;
    SELECT COALESCE(MAX(id_envio), 0) + 1 INTO v_shipping_id FROM tab_Envios;
    INSERT INTO tab_Envios (
        id_envio, id_orden, id_direccion_envio, metodo_envio, estado_envio, fecha_envio, fecha_entrega_estimada, costo_envio, fec_insert, usr_insert
    ) VALUES (
        v_shipping_id, v_order_id, v_addr_id, 'Despacho Asegurado RD-Watch', 'pendiente', NOW(), NOW() + INTERVAL '48 hours', 15000, NOW(), 'logistics_kernel'
    );

    -- PASO 9: Inicialización del Recibo de Pago.
    -- LOCK previene condición de carrera en generación concurrente de IDs.
    LOCK TABLE tab_Pagos IN EXCLUSIVE MODE;
    SELECT COALESCE(MAX(id_pago), 0) + 1 INTO v_payment_id FROM tab_Pagos;
    INSERT INTO tab_Pagos (
        id_pago, id_orden, monto, id_metodo_pago, estado_pago, fecha_pago, fec_insert, usr_insert
    ) VALUES (
        v_payment_id, v_order_id, v_total + 15000, 1, 'pendiente', NOW(), NOW(), 'finances_kernel'
    );

    -- PASO 10: Purga del Carrito (Cierre de Transacción).
    DELETE FROM tab_Carrito_Detalle WHERE id_carrito = v_cart_id;
    UPDATE tab_Carrito SET 
        estado_carrito = 'convertido_a_orden', 
        fec_update = NOW(), 
        usr_update = 'checkout_done'
    WHERE id_carrito = v_cart_id;

    -- Retorno a PHP para confirmación visual al cliente.
    RETURN json_build_object(
        'ok', true,
        'msg', 'Transacción exitosa. Su orden #' || v_order_id || ' ha sido enviada a validación financiera.',
        'order_id', v_order_id,
        'payment_id', v_payment_id
    );
END;
$$ LANGUAGE plpgsql;


-- ██████████████████████████████████████████████████████████
-- ██  SECCIÓN 3: GESTIÓN DE PEDIDOS (Admin)               ██
-- ██████████████████████████████████████████████████████████
--
-- Los pedidos son órdenes ya confirmadas. Solo admin puede
-- ver la lista completa y cambiar el estado logístico.


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 8: fn_orders_list                              ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Proveer un listado de órdenes con filtros    ║
-- ║               multidimensionales para administración.    ║
-- ║  Llamada PHP: SELECT fn_orders_list(null, 'Juan',...)    ║
-- ║  Retorna    : JSON array [{id, cliente, estado, ...},...]║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin abre la sección "Pedidos" del panel.          ║
-- ║  2. Opcionalmente aplica filtros (estado, nombre, fecha).║
-- ║  3. PHP ejecuta fn_orders_list con parámetros NULL-safe. ║
-- ║  4. JOINs con Usuarios y Pagos enriquecen los datos.    ║
-- ║  5. Retorna JSON array → PHP renderiza tabla de pedidos. ║
-- ║                                                         ║
-- ║  LÓGICA DE FILTRADO:                                     ║
-- ║  Aplica WHERE dinámico mediante COALESCE/NULL para que   ║
-- ║  el admin pueda filtrar por estado, nombre, email o      ║
-- ║  rango de fechas de forma independiente.                 ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE OR REPLACE FUNCTION fn_orders_list(
    p_estado     tab_Orden.estado_orden%TYPE DEFAULT NULL,   -- Filtro por estado logístico
    p_busqueda   TEXT DEFAULT NULL,   -- Búsqueda por cliente/correo
    p_date_from  TEXT DEFAULT NULL,   -- Límite inferior temporal
    p_date_to    TEXT DEFAULT NULL    -- Límite superior temporal
)
RETURNS JSON
AS $$
DECLARE
    v_result JSON; -- Buffer de salida
BEGIN
    -- Captura y agregación de órdenes con JOINs a Usuarios y Pagos.
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_result FROM (
        SELECT
            o.id_orden,              -- Referencia única
            u.nom_usuario AS cliente, -- Nombre del comprador
            u.correo_usuario AS email_cliente, -- Canal de contacto
            o.fecha_orden AS fecha,  -- Momento de la compra
            o.estado_orden,          -- Situación logística
            o.total_orden,           -- Monto transaccional
            -- Verificación de existencia de comprobante (0/1) para el UI.
            (CASE WHEN p.comprobante_ruta IS NOT NULL THEN 1 ELSE 0 END) AS tiene_comprobante,
            p.estado_pago            -- Situación financiera
        FROM tab_Orden o
        JOIN tab_Usuarios u ON o.id_usuario = u.id_usuario -- Nexo con el cliente
        LEFT JOIN tab_Pagos p ON o.id_orden = p.id_orden -- Nexo con la caja (opcional)
        WHERE
            -- Aplicación de filtros opcionales.
            (p_estado IS NULL OR o.estado_orden = p_estado)
            AND (p_busqueda IS NULL OR (u.nom_usuario ILIKE '%' || p_busqueda || '%' OR u.correo_usuario ILIKE '%' || p_busqueda || '%'))
            AND (p_date_from IS NULL OR o.fecha_orden >= p_date_from::TIMESTAMP)
            AND (p_date_to IS NULL OR o.fecha_orden <= p_date_to::TIMESTAMP)
        ORDER BY o.id_orden DESC -- Visibilidad de lo más reciente primero
    ) t;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 9: fn_orders_update_status                     ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Sincronizar el estado real del flujo de      ║
-- ║               trabajo logístico de una orden.           ║
-- ║  Llamada PHP: SELECT fn_orders_update_status(1, 'enviado')║
-- ║  Retorna    : JSON {ok: bool, msg: text}                ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin selecciona nuevo estado en el dropdown.       ║
-- ║  2. PHP ejecuta fn_orders_update_status(id, estado).   ║
-- ║  3. La función valida contra lista blanca de estados.   ║
-- ║  4. Si válido → UPDATE con sello de auditoría.          ║
-- ║  5. Retorna {ok, msg} → PHP confirma al admin.          ║
-- ║                                                         ║
-- ║  SEGURIDAD:                                             ║
-- ║  Valida el nuevo estado contra una lista blanca para     ║
-- ║  prevenir inyecciones de estados no controlados.        ║
-- ╚══════════════════════════════════════════════════════════╝
DROP FUNCTION IF EXISTS fn_orders_update_status(bigint, text);
DROP FUNCTION IF EXISTS fn_orders_update_status(integer, text);
CREATE OR REPLACE FUNCTION fn_orders_update_status(
    p_order_id   tab_Orden.id_orden%TYPE,   -- ID de la orden objeto del cambio
    p_new_status tab_Orden.estado_orden%TYPE      -- Etiqueta del nuevo estado
)
RETURNS JSON
AS $$
BEGIN
    -- VALIDACIÓN: Restricción de dominio de estados.
    IF p_new_status NOT IN ('pendiente', 'confirmado', 'enviado', 'cancelado', 'entregado') THEN
        RETURN json_build_object('ok', false,
            'msg', 'Transición no permitida: El estado indicado no pertenece al workflow logístico.');
    END IF;

    -- DML: Actualización con sello de auditoría.
    UPDATE tab_Orden
    SET estado_orden = p_new_status, 
        usr_update = 'admin_operator', 
        fec_update = NOW()
    WHERE id_orden = p_order_id;

    RETURN json_build_object('ok', true,
        'msg', 'La orden ha transitado exitosamente al estado: ' || p_new_status);
END;
$$ LANGUAGE plpgsql;


-- ██████████████████████████████████████████████████████████
-- ██  SECCIÓN 4: CITAS / RESERVAS TÉCNICAS                ██
-- ██████████████████████████████████████████████████████████
--
-- Las citas son reservas de servicios técnicos del taller.
-- Tienen DOS vistas:
--   Admin: ve TODAS las citas con datos del cliente
--   Cliente: solo ve SUS propias citas
-- Admin puede cambiar el estado (pendiente → confirmada → completada)


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 10: fn_citas_list_admin                        ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Exponer la agenda técnica completa para     ║
-- ║               la gestión operativa del taller.          ║
-- ║  Llamada PHP: SELECT fn_citas_list_admin()              ║
-- ║  Retorna    : JSON array [{id, cliente, servicio, ...}] ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin abre la sección "Citas" del panel.            ║
-- ║  2. PHP ejecuta SELECT fn_citas_list_admin().           ║
-- ║  3. JOINs con Servicios y Usuarios enriquecen datos.   ║
-- ║  4. Retorna JSON array → PHP renderiza la agenda.       ║
-- ║                                                         ║
-- ║  JOINS INTEGRADOS:                                      ║
-- ║  Reservas + Servicios (catálogo) + Usuarios (clientes). ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE OR REPLACE FUNCTION fn_citas_list_admin()
RETURNS JSON
AS $$
DECLARE
    v_result JSON; -- Buffer de salida
BEGIN
    -- Compilación de citas con resolución de identidades (Nombres en vez de IDs).
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_result FROM (
        SELECT
            r.id_reserva,
            r.id_usuario,
            u.nom_usuario AS cliente,         -- Identidad del propietario
            s.nom_servicio AS nombre_servicio, -- Tipo de trabajo técnico
            r.fecha_preferida,                 -- Fecha agendada
            r.prioridad,                       -- Nivel de urgencia
            r.estado_reserva AS estado,        -- Situación actual de la cita
            r.notas_cliente AS notas           -- Requerimiento específico
        FROM tab_Reservas r
        LEFT JOIN tab_Servicios s ON r.id_servicio = s.id_servicio -- Enlace al catálogo técnico
        LEFT JOIN tab_Usuarios u ON r.id_usuario = u.id_usuario    -- Enlace al maestro de clientes
        ORDER BY r.fecha_reserva DESC -- Prioridad visual en ingresos recientes
    ) t;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 11: fn_citas_list_cliente                      ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Proveer al cliente una vista de sus         ║
-- ║               propios agendamientos técnicos.           ║
-- ║  Llamada PHP: SELECT fn_citas_list_cliente(user_id)     ║
-- ║  Retorna    : JSON array [{id, servicio, fecha, ...}]   ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Cliente abre la sección "Mis Citas" en su panel.    ║
-- ║  2. PHP ejecuta fn_citas_list_cliente(user_id).         ║
-- ║  3. WHERE estricto por id_usuario (protección IDOR).    ║
-- ║  4. JOIN con Servicios resuelve nombres técnicos.       ║
-- ║  5. Retorna JSON array → PHP renderiza historial.       ║
-- ║                                                         ║
-- ║  BLINDAJE IDOR:                                         ║
-- ║  Filtra estrictamente por id_usuario, impidiendo que un ║
-- ║  usuario vea citas de terceros modificando el parámetro.║
-- ╚══════════════════════════════════════════════════════════╝
DROP FUNCTION IF EXISTS fn_citas_list_cliente(bigint);
DROP FUNCTION IF EXISTS fn_citas_list_cliente(integer);
CREATE OR REPLACE FUNCTION fn_citas_list_cliente(
    p_user_id tab_Usuarios.id_usuario%TYPE   -- ID del usuario autenticado
)
RETURNS JSON
AS $$
DECLARE
    v_result JSON;
BEGIN
    -- Selección acotada al ámbito de seguridad del usuario.
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_result FROM (
        SELECT
            r.id_reserva,
            s.nom_servicio AS nombre_servicio,
            r.fecha_preferida,
            r.prioridad,
            r.estado_reserva AS estado,
            r.notas_cliente AS notas
        FROM tab_Reservas r
        JOIN tab_Servicios s ON r.id_servicio = s.id_servicio
        WHERE r.id_usuario = p_user_id  -- Barrera de seguridad IDOR
        ORDER BY r.fecha_reserva DESC
    ) t;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 12: fn_citas_create                            ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Registrar una nueva solicitud de servicio   ║
-- ║               técnico en la agenda del taller.          ║
-- ║  Llamada PHP: SELECT fn_citas_create(user, serv, ...)    ║
-- ║  Retorna    : JSON {ok: bool, msg: text}                ║
-- ║                                                         ║
-- ║  ACCESO: El cliente puede solicitar citas 24/7.         ║
-- ║  Las restricciones aplican a la FECHA SELECCIONADA:     ║
-- ║                                                         ║
-- ║  REGLAS DE NEGOCIO (28/04/2026):                        ║
-- ║  1. Anticipación: fecha preferida >= hoy + 2 días.      ║
-- ║  2. Fecha preferida NO puede ser domingo.               ║
-- ║  3. Anti-Duplicado: Misma cita+fecha activa.            ║
-- ║  4. Límite diario cliente: máx 1 solicitud/día.         ║
-- ║  5. Límite semanal cliente: máx 2 solicitudes/semana.   ║
-- ║  6. Límite global: máx 10 citas por fecha preferida.    ║
-- ║                                                         ║
-- ║  NOTA: Solo citas 'pendiente'/'confirmada' cuentan.     ║
-- ║  Zona horaria forzada a America/Bogota.                 ║
-- ╚══════════════════════════════════════════════════════════╝
DROP FUNCTION IF EXISTS fn_citas_create(bigint, bigint, date, text, text);
DROP FUNCTION IF EXISTS fn_citas_create(integer, integer, date, text, text);
CREATE OR REPLACE FUNCTION fn_citas_create(
    p_user_id     tab_Usuarios.id_usuario%TYPE,   -- ID del cliente solicitante
    p_servicio_id tab_Servicios.id_servicio%TYPE,   -- ID del tipo de servicio (catálogo)
    p_fecha       tab_Reservas.fecha_preferida%TYPE,     -- Jornada preferida para el taller
    p_prioridad   tab_Reservas.prioridad%TYPE,     -- Escala de urgencia (ej: 'normal')
    p_notas       tab_Reservas.notas_cliente%TYPE      -- Detalle del fallo o requerimiento
)
RETURNS JSON
AS $$
DECLARE
    v_new_id   tab_Reservas.id_reserva%TYPE;
    v_now      TIMESTAMP;  -- Timestamp en zona horaria local
    v_count    SMALLINT;   -- Buffer reutilizable para conteos
BEGIN
    -- ═══════════════════════════════════════════
    -- FORZAR ZONA HORARIA COLOMBIA (UTC-5)
    -- ═══════════════════════════════════════════
    SET LOCAL timezone = 'America/Bogota';
    v_now := NOW();

    -- ═══════════════════════════════════════════
    -- VALIDACIÓN 1: ANTICIPACIÓN MÍNIMA (2 días)
    -- ═══════════════════════════════════════════
    IF p_fecha < (CURRENT_DATE + 2) THEN
        RETURN json_build_object('ok', false,
            'msg', 'Fecha inválida: La fecha preferida debe ser al menos 2 días después de hoy (' || TO_CHAR(CURRENT_DATE + 2, 'DD/MM/YYYY') || ' en adelante).');
    END IF;

    -- ═══════════════════════════════════════════
    -- VALIDACIÓN 2: FECHA PREFERIDA NO PUEDE SER DOMINGO
    -- DOW: 0=Dom, 1=Lun ... 6=Sáb
    -- ═══════════════════════════════════════════
    IF EXTRACT(DOW FROM p_fecha) = 0 THEN
        RETURN json_build_object('ok', false,
            'msg', 'Fecha no disponible: No se atienden servicios los domingos. Horario disponible: Lunes a Viernes 10AM–6PM, Sábados 10AM–3PM.');
    END IF;

    -- ═══════════════════════════════════════════
    -- VALIDACIÓN 3: ANTI-DUPLICADO
    -- ═══════════════════════════════════════════
    IF EXISTS (
        SELECT 1 FROM tab_Reservas
        WHERE id_usuario = p_user_id
          AND id_servicio = p_servicio_id
          AND fecha_preferida = p_fecha
          AND estado_reserva IN ('pendiente', 'confirmada')
    ) THEN
        RETURN json_build_object('ok', false,
            'msg', 'Acción denegada: Ya cuenta con una solicitud activa para este servicio en la fecha indicada.');
    END IF;

    -- ═══════════════════════════════════════════
    -- VALIDACIÓN 4: LÍMITE DIARIO POR CLIENTE (máx 1/día)
    -- Basado en fecha de creación (anti-spam)
    -- ═══════════════════════════════════════════
    SELECT COUNT(1) INTO v_count
    FROM tab_Reservas
    WHERE id_usuario = p_user_id
      AND fecha_reserva::DATE = CURRENT_DATE
      AND estado_reserva IN ('pendiente', 'confirmada');

    IF v_count >= 1 THEN
        RETURN json_build_object('ok', false,
            'msg', 'Límite alcanzado: Solo puede realizar 1 solicitud de servicio por día. Intente nuevamente mañana.');
    END IF;

    -- ═══════════════════════════════════════════
    -- VALIDACIÓN 5: LÍMITE SEMANAL POR CLIENTE (máx 2/semana)
    -- Basado en fecha de creación (anti-spam)
    -- ═══════════════════════════════════════════
    SELECT COUNT(1) INTO v_count
    FROM tab_Reservas
    WHERE id_usuario = p_user_id
      AND fecha_reserva >= DATE_TRUNC('week', CURRENT_DATE)
      AND estado_reserva IN ('pendiente', 'confirmada');

    IF v_count >= 2 THEN
        RETURN json_build_object('ok', false,
            'msg', 'Límite semanal alcanzado: Solo puede realizar 2 solicitudes por semana. Intente la próxima semana.');
    END IF;

    -- ═══════════════════════════════════════════
    -- VALIDACIÓN 6: LÍMITE GLOBAL DIARIO (máx 10 citas/día)
    -- Basado en FECHA PREFERIDA (capacidad del taller)
    -- ═══════════════════════════════════════════
    SELECT COUNT(1) INTO v_count
    FROM tab_Reservas
    WHERE fecha_preferida = p_fecha
      AND estado_reserva IN ('pendiente', 'confirmada');

    IF v_count >= 10 THEN
        RETURN json_build_object('ok', false,
            'msg', 'Agenda completa: La fecha seleccionada ya tiene el máximo de citas permitidas (10). Por favor, seleccione otro día.');
    END IF;

    -- ═══════════════════════════════════════════
    -- INSERCIÓN: Registro formal en la agenda
    -- LOCK previene condición de carrera en generación concurrente de IDs.
    -- ═══════════════════════════════════════════
    LOCK TABLE tab_Reservas IN EXCLUSIVE MODE;
    SELECT COALESCE(MAX(r.id_reserva), 0) + 1 INTO v_new_id FROM tab_Reservas r;

    INSERT INTO tab_Reservas (
        id_reserva, 
        id_usuario, 
        id_servicio, 
        fecha_preferida, 
        notas_cliente, 
        prioridad, 
        estado_reserva, 
        fecha_reserva, 
        usr_insert, 
        fec_insert
    ) VALUES (
        v_new_id, 
        p_user_id, 
        p_servicio_id, 
        p_fecha, 
        p_notas, 
        p_prioridad, 
        'pendiente', 
        v_now, 
        'usr_web_client', 
        v_now
    );

    RETURN json_build_object('ok', true, 'msg', 'Su solicitud ha sido agendada exitosamente. Un técnico la revisará a la brevedad.');
END;
$$ LANGUAGE plpgsql;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 13: fn_citas_update_status                     ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Administrar el flujo de estados de una      ║
-- ║               cita técnica (Trazabilidad Taller).       ║
-- ║  Llamada PHP: SELECT fn_citas_update_status(1, 'confirm')║
-- ║  Retorna    : JSON {ok: true, msg: text}                ║
-- ║                                                         ║
-- ║  REGLAS (28/04/2026):                                   ║
-- ║  - Cancelación: Solo si fecha_preferida > hoy + 1 día.  ║
-- ║  - Admin (p_admin_id = 'admin_%') puede cancelar sin    ║
-- ║    restricción de anticipación.                         ║
-- ║  - Auditoría: usr_update + fec_update siempre.          ║
-- ╚══════════════════════════════════════════════════════════╝
DROP FUNCTION IF EXISTS fn_citas_update_status(bigint, text, text);
DROP FUNCTION IF EXISTS fn_citas_update_status(integer, text, text);
CREATE OR REPLACE FUNCTION fn_citas_update_status(
    p_reserva_id  tab_Reservas.id_reserva%TYPE,  -- ID de la reserva a gestionar
    p_new_status  tab_Reservas.estado_reserva%TYPE,    -- Nuevo estado (confirmada, cancelada, etc)
    p_admin_id    tab_Reservas.usr_update%TYPE     -- Sello del operador actuante
)
RETURNS JSON
AS $$
DECLARE
    v_fecha_pref tab_Reservas.fecha_preferida%TYPE;
BEGIN
    -- Forzar zona horaria Colombia
    SET LOCAL timezone = 'America/Bogota';

    -- ═══════════════════════════════════════════
    -- VALIDACIÓN: Cancelación con anticipación mínima (1 día)
    -- Solo aplica a clientes (p_admin_id NO empieza con 'admin_')
    -- ═══════════════════════════════════════════
    IF p_new_status = 'cancelada' AND LEFT(p_admin_id, 6) <> 'admin_' THEN
        SELECT r.fecha_preferida INTO v_fecha_pref
        FROM tab_Reservas r
        WHERE r.id_reserva = p_reserva_id;

        IF v_fecha_pref IS NULL THEN
            RETURN json_build_object('ok', false,
                'msg', 'Error: No se encontró la cita especificada.');
        END IF;

        IF v_fecha_pref <= (CURRENT_DATE + 1) THEN
            RETURN json_build_object('ok', false,
                'msg', 'No es posible cancelar: Las citas solo pueden cancelarse con al menos 1 día de anticipación antes de la fecha programada.');
        END IF;
    END IF;

    -- DML focalizado con inyección de timestamps de control.
    UPDATE tab_Reservas
    SET estado_reserva = p_new_status, 
        usr_update = p_admin_id, 
        fec_update = NOW()
    WHERE id_reserva = p_reserva_id;

    RETURN json_build_object('ok', true, 'msg', 'El estado de la cita técnica ha sido actualizado.');
END;
$$ LANGUAGE plpgsql;


-- ██████████████████████████████████████████████████████████
-- ██  SECCIÓN 5: CONTACTO (Landing Page)                  ██
-- ██████████████████████████████████████████████████████████
--
-- El formulario de contacto del landing page crea reservas
-- directamente en tab_Reservas con notas descriptivas.
-- Solo usuarios logueados pueden agendar (anti-spam).


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 14: fn_contacto_public_create                  ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Registrar de forma segura un mensaje de     ║
-- ║               contacto público en tab_Contacto.         ║
-- ║  Llamada PHP: SELECT fn_contacto_public_create(...)     ║
-- ║  Retorna    : JSON {ok: true, msg: text}                ║
-- ║                                                         ║
-- ║  FLUJO ATÓMICO:                                         ║
-- ║  1. Recibe datos limpios del frontend (nombre, correo,  ║
-- ║     teléfono, mensaje).                                 ║
-- ║  2. Valida si hay spam (mismo correo + mismo mensaje    ║
-- ║     en los últimos 5 minutos).                          ║
-- ║  3. Genera ID secuencial seguro.                        ║
-- ║  4. Inserta en tab_Contacto.                            ║
-- ║  5. Retorna acuse de recibo.                            ║
-- ╚══════════════════════════════════════════════════════════╝
DROP FUNCTION IF EXISTS fn_contacto_public_create(text, text, bigint, text);
CREATE OR REPLACE FUNCTION fn_contacto_public_create(
    p_nombre_remitente tab_Contacto.nombre_remitente%TYPE,
    p_correo_remitente tab_Contacto.correo_remitente%TYPE,
    p_telefono_remitente tab_Contacto.telefono_remitente%TYPE,
    p_mensaje tab_Contacto.mensaje%TYPE
)
RETURNS JSON
AS $$
DECLARE
    v_new_id tab_Contacto.id_contacto%TYPE;
BEGIN
    -- BARRERA ANTI-SPAM (NATIVA)
    -- Evita que el mismo correo envíe el mismo texto en un lapso muy corto.
    IF EXISTS (
        SELECT 1 FROM tab_Contacto
        WHERE correo_remitente = p_correo_remitente
          AND mensaje = p_mensaje
          AND fec_insert > (NOW() - INTERVAL '5 minutes')
    ) THEN
        RETURN json_build_object('ok', false,
            'msg', 'Hemos recibido tu mensaje anterior. Por favor, espera unos minutos antes de enviar otro.');
    END IF;

    -- GENERACIÓN DE PK
    -- LOCK previene condición de carrera en generación concurrente de IDs.
    LOCK TABLE tab_Contacto IN EXCLUSIVE MODE;
    SELECT COALESCE(MAX(id_contacto), 0) + 1 INTO v_new_id FROM tab_Contacto;

    -- INSERCIÓN EN TAB_CONTACTO
    INSERT INTO tab_Contacto (
        id_contacto,
        nombre_remitente,
        correo_remitente,
        telefono_remitente,
        mensaje,
        estado,
        fecha_envio,
        usr_insert,
        fec_insert
    ) VALUES (
        v_new_id,
        p_nombre_remitente,
        p_correo_remitente,
        p_telefono_remitente,
        p_mensaje,
        'pendiente',
        NOW(),
        'SYSTEM_PUBLIC_CONTACT',
        NOW()
    );

    RETURN json_build_object(
        'ok', true,
        'msg', '¡Mensaje enviado con éxito! Un especialista de Relojería Durán te contactará pronto.'
    );
END;
$$ LANGUAGE plpgsql;
