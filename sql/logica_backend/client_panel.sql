-- ============================================================
-- MÓDULO: PANEL DE CLIENTE Y RESEÑAS (client_panel.sql)
-- ============================================================
-- Fase        : 4 de 5 — Panel de Cliente, Reseñas, Geografía
-- ============================================================
--
-- ╔══════════════════════════════════════════════════════════╗
-- ║  PRINCIPIO: OCULTACIÓN TOTAL                           ║
-- ║  PHP NUNCA ve nombres de tablas ni columnas.            ║
-- ║  Todas las funciones retornan JSON puro.                ║
-- ╚══════════════════════════════════════════════════════════╝
--
-- FUNCIONES EN ESTE MÓDULO (16 total):
-- ────────────────────────────────────
-- PANEL DE USUARIO (5):
--   1. fn_user_get_profile      → Perfil personal del usuario
--   2. fn_user_get_orders       → Historial de pedidos del cliente
--   3. fn_user_get_dashboard    → Conteos para dashboard rápido
--   4. fn_user_update_profile   → Actualizar nombre/email/teléfono
--   5. fn_user_update_address   → Sincronizar dirección principal
-- RESEÑAS (3):
--   6. fn_reviews_list          → Últimas 10 reseñas públicas
--   7. fn_reviews_check_dup     → Anti-duplicado de comentarios
--   8. fn_reviews_create        → Crear nueva reseña
-- GEOGRAFÍA (2):
--   9. fn_geo_departamentos     → Catálogo de departamentos
--  10. fn_geo_ciudades          → Ciudades filtradas por depto
-- ADMIN CLIENTES (3):
--  11. fn_admin_list_clients    → Listar todos los clientes
--  12. fn_admin_check_role      → Verificar rol antes de modificar
--  13. fn_admin_toggle_client   → Activar/desactivar cliente
-- ADMIN SETTINGS (3):
--  14. fn_admin_get_settings    → Obtener configuración global
--  15. fn_admin_get_stats       → Estadísticas generales de la tienda
--  16. fn_admin_update_settings → Actualizar configuración (simulado)
--
-- TABLAS QUE ESTE MÓDULO TOCA (invisibles para PHP):
-- ────────────────────────────────────
-- tab_Usuarios         → Perfil y datos de contacto
-- tab_Orden            → Pedidos (lectura)
-- tab_Reservas         → Citas (conteo)
-- tab_Direcciones_Envio → Direcciones de envío
-- tab_Ciudades         → Catálogo geográfico
-- tab_Departamentos    → División territorial
-- tab_Opiniones        → Reseñas de clientes
-- ============================================================


-- ██████████████████████████████████████████████████████████
-- ██  SECCIÓN 1: PANEL DE USUARIO                         ██
-- ██████████████████████████████████████████████████████████
--
-- Estas funciones alimentan el panel de cliente ("Mi Cuenta").
-- Todas usan $_SESSION['user_id'] para proteger contra IDOR.


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 1: fn_user_get_profile                         ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Extraer la ficha de perfil pública del      ║
-- ║               usuario autenticado para su panel lateral. ║
-- ║  Llamada PHP: SELECT fn_user_get_profile(user_id)       ║
-- ║  Retorna    : JSON {id, nombre, email, telefono, ...}   ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Cliente accede a "Mi Cuenta" en el frontend.        ║
-- ║  2. PHP ejecuta SELECT fn_user_get_profile(user_id).    ║
-- ║  3. Solo campos no sensibles se incluyen en la respuesta.║
-- ║  4. Retorna JSON → PHP renderiza la ficha de perfil.    ║
-- ║                                                         ║
-- ║  BLINDAJE DE PRIVACIDAD:                                 ║
-- ║  Solo retorna campos de contacto y estado. NUNCA expone  ║
-- ║  el hash de contraseña ni los tokens de sesión.         ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_user_get_profile(
    p_user_id tab_Usuarios.id_usuario%TYPE  -- Identificador único del usuario
)
RETURNS JSON
AS $$
DECLARE
    v_result JSON; -- Contenedor de salida
BEGIN
    -- Selección estructurada de atributos no sensibles.
    SELECT row_to_json(t) INTO v_result FROM (
        SELECT
            u.id_usuario,
            u.nom_usuario,
            u.correo_usuario,
            u.num_telefono_usuario,
            u.direccion_principal,
            u.activo,
            u.fecha_registro
        FROM tab_Usuarios u
        WHERE u.id_usuario = p_user_id -- Filtro de propiedad única
    ) t;

    -- Validación de existencia previa al retorno.
    IF v_result IS NULL THEN
        RETURN json_build_object('ok', false, 'msg', 'Inconsistencia: El perfil solicitado no existe en la base de datos.');
    END IF;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 2: fn_user_get_orders                          ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Recuperar la bitácora histórica de compras  ║
-- ║               realizadas por el cliente identificado.    ║
-- ║  Llamada PHP: SELECT fn_user_get_orders(user_id)        ║
-- ║  Retorna    : JSON array [{id, concepto, fecha, total},..]║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Cliente abre "Mis Pedidos" en su panel.             ║
-- ║  2. PHP ejecuta SELECT fn_user_get_orders(user_id).     ║
-- ║  3. WHERE restringe al propietario (Anti-IDOR).         ║
-- ║  4. Retorna JSON array → PHP renderiza historial.       ║
-- ║                                                         ║
-- ║  SEGURIDAD ANTI-IDOR:                                    ║
-- ║  La cláusula WHERE restringe los datos al propietario,   ║
-- ║  evitando que un usuario vea órdenes de otros.          ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_user_get_orders(
    p_user_id tab_Usuarios.id_usuario%TYPE -- ID del usuario autenticado
)
RETURNS JSON
AS $$
DECLARE
    v_result JSON; -- Acumulador de órdenes
BEGIN
    -- Agregación de filas en formato JSON compatible con el frontend.
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_result FROM (
        SELECT
            o.id_orden,             -- Referencia de la transacción
            o.concepto,             -- Glosa descriptiva
            o.fecha_orden AS fecha, -- Instante del pedido
            o.total_orden,          -- Monto final pagado
            o.estado_orden          -- Situación (pendiente/entregado/etc)
        FROM tab_Orden o
        WHERE o.id_usuario = p_user_id -- Barrera de seguridad IDOR
        ORDER BY o.fecha_orden DESC    -- Últimas compras al inicio
    ) t;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 3: fn_user_get_dashboard                       ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Generar métricas de resumen para la vista   ║
-- ║               inicial del panel de control del cliente.  ║
-- ║  Llamada PHP: SELECT fn_user_get_dashboard(user_id)     ║
-- ║  Retorna    : JSON {pedidosActivos, completados, citas}  ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Cliente accede a la vista principal de su panel.    ║
-- ║  2. PHP ejecuta SELECT fn_user_get_dashboard(user_id).  ║
-- ║  3. 3 conteos cruzados (activos, cerrados, citas).      ║
-- ║  4. Retorna JSON → PHP pobla las tarjetas del dashboard.║
-- ║                                                         ║
-- ║  EFICIENCIA:                                             ║
-- ║  Consolida 3 conteos cruzados en una sola transacción    ║
-- ║  para minimizar la latencia de red entre PHP y DB.      ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_user_get_dashboard(
    p_user_id tab_Usuarios.id_usuario%TYPE -- Ámbito del dashboard
)
RETURNS JSON
AS $$
DECLARE
    v_activos     INTEGER; -- Pedidos en tránsito
    v_completados INTEGER; -- Pedidos cerrados exitosamente
    v_citas       INTEGER; -- Reservas técnicas no atendidas
BEGIN
    -- Métrica 1: Órdenes en flujo logístico activo.
    SELECT COUNT(o.id_orden) INTO v_activos
    FROM tab_Orden o
    WHERE o.id_usuario = p_user_id
      AND o.estado_orden IN ('pendiente', 'confirmado', 'enviado');

    -- Métrica 2: Órdenes finalizadas (Historial cerrado).
    SELECT COUNT(o.id_orden) INTO v_completados
    FROM tab_Orden o
    WHERE o.id_usuario = p_user_id
      AND o.estado_orden = 'entregado';

    -- Métrica 3: Servicios técnicos pendientes de atención.
    SELECT COUNT(r.id_reserva) INTO v_citas
    FROM tab_Reservas r
    WHERE r.id_usuario = p_user_id
      AND r.estado_reserva = 'pendiente';

    -- Empaquetamiento final de métricas.
    RETURN json_build_object(
        'pedidosActivos', v_activos,
        'pedidosCompletados', v_completados,
        'citasPendientes', v_citas
    );
END;
$$ LANGUAGE plpgsql STABLE;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 4: fn_user_update_profile                      ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Actualizar los datos maestros de contacto   ║
-- ║               del usuario desde su configuración.        ║
-- ║  Llamada PHP: SELECT fn_user_update_profile(...)         ║
-- ║  Retorna    : JSON {ok: bool, msg: text}                ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Cliente edita nombre/email/teléfono en su panel.    ║
-- ║  2. PHP ejecuta fn_user_update_profile(...).            ║
-- ║  3. Verifica unicidad del email en el sistema.          ║
-- ║  4. Si libre → UPDATE con sello de auditoría.           ║
-- ║  5. Retorna {ok, msg} → PHP confirma al cliente.        ║
-- ║                                                         ║
-- ║  REGLA DE UNICIDAD:                                      ║
-- ║  Verifica que el nuevo email no esté en uso por otra     ║
-- ║  cuenta para prevenir robos de identidad o duplicados.   ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_user_update_profile(
    p_user_id  tab_Usuarios.id_usuario%TYPE,  -- ID del usuario actual
    p_nombre   tab_Usuarios.nom_usuario%TYPE,    -- Nuevo nombre/alias
    p_email    tab_Usuarios.correo_usuario%TYPE,    -- Nuevo correo electrónico
    p_telefono TEXT     -- Nuevo número telefónico (TEXT desde PHP, cast interno)
)
RETURNS JSON
AS $$
BEGIN
    -- BARRERA DE IDENTIDAD: El email debe ser único en el sistema.
    IF EXISTS (
        SELECT 1 FROM tab_Usuarios
        WHERE correo_usuario = p_email AND id_usuario <> p_user_id
    ) THEN
        RETURN json_build_object('ok', false,
            'msg', 'Acción denegada: El correo electrónico ya se encuentra registrado bajo otra identidad.');
    END IF;

    -- DML: Persistencia de cambios con sello de auto-actualización.
    UPDATE tab_Usuarios
    SET nom_usuario = p_nombre,
        correo_usuario = p_email,
        num_telefono_usuario = p_telefono::BIGINT, -- Cast explícito a numérico
        fec_update = NOW(),
        usr_update = 'self_update' -- Auditoría de cambio por el usuario
    WHERE id_usuario = p_user_id;

    RETURN json_build_object('ok', true, 'msg', 'Su perfil ha sido actualizado con éxito.');
END;
$$ LANGUAGE plpgsql;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 5: fn_user_update_address                      ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Mantener sincronía entre la dirección del    ║
-- ║               perfil y la agenda de envíos del cliente.  ║
-- ║  Llamada PHP: SELECT fn_user_update_address(...)         ║
-- ║  Retorna    : JSON {ok: bool, msg: text}                ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Cliente edita dirección en su panel de envío.       ║
-- ║  2. PHP ejecuta fn_user_update_address(...).            ║
-- ║  3. Anti-flood: verifica duplicidad de dirección.       ║
-- ║  4. Sincroniza perfil + agenda de envíos atómicamente.  ║
-- ║  5. Retorna {ok, msg} → PHP confirma al cliente.        ║
-- ║                                                         ║
-- ║  FLUJO ATÓMICO:                                          ║
-- ║  1. Actualiza el campo rápido 'direccion_principal'.     ║
-- ║  2. Busca o crea la entrada en 'tab_Direcciones_Envio'.  ║
-- ║  3. Marca la dirección como predeterminada (TRUE).       ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_user_update_address(
    p_user_id   tab_Usuarios.id_usuario%TYPE,  -- Propietario de la dirección
    p_direccion tab_Direcciones_Envio.direccion_completa%TYPE,    -- Texto completo del domicilio
    p_ciudad_id tab_Ciudades.id_ciudad%TYPE, -- Enlace al catálogo de ciudades
    p_postal    tab_Direcciones_Envio.codigo_postal%TYPE     -- Código postal
)
RETURNS JSON
AS $$
DECLARE
    v_existing_id tab_Direcciones_Envio.id_direccion%TYPE; -- Puntero a dirección encontrada
    v_new_id      tab_Direcciones_Envio.id_direccion%TYPE; -- Generador de ID para nueva dirección
BEGIN
    -- PASO 1: Sincronización del Perfil Maestro (Update rápido).
    UPDATE tab_Usuarios
    SET direccion_principal = p_direccion, 
        fec_update = NOW(), 
        usr_update = 'addr_sync'
    WHERE id_usuario = p_user_id;

    -- PASO 2: Gestión de la agenda de envíos.
    -- Buscamos si la dirección ya existe para este usuario.
    SELECT id_direccion INTO v_existing_id
    FROM tab_Direcciones_Envio
    WHERE id_usuario = p_user_id
      AND direccion_completa = p_direccion
      AND id_ciudad = p_ciudad_id;

    -- PASO 3: Desmarcar cualquier otra dirección predeterminada previa.
    UPDATE tab_Direcciones_Envio
    SET es_predeterminada = FALSE
    WHERE id_usuario = p_user_id;

    -- PASO 4: Escritura o Actualización.
    IF v_existing_id IS NOT NULL THEN
        -- Si existe, la activamos como predeterminada y actualizamos código postal si cambió.
        UPDATE tab_Direcciones_Envio
        SET es_predeterminada = TRUE,
            codigo_postal = p_postal,
            fec_update = NOW(),
            usr_update = 'addr_sync'
        WHERE id_direccion = v_existing_id;
    ELSE
        -- Si no existe, creamos una nueva.
        -- LOCK previene condición de carrera en generación concurrente de IDs.
        LOCK TABLE tab_Direcciones_Envio IN EXCLUSIVE MODE;
        SELECT COALESCE(MAX(d.id_direccion), 0) + 1 INTO v_new_id FROM tab_Direcciones_Envio d;
        INSERT INTO tab_Direcciones_Envio (
            id_direccion, id_usuario, direccion_completa, id_ciudad, codigo_postal, es_predeterminada, fec_insert, usr_insert
        ) VALUES (
            v_new_id, p_user_id, p_direccion, p_ciudad_id, p_postal, TRUE, NOW(), 'addr_sync'
        );
    END IF;

    RETURN json_build_object('ok', true, 'msg', 'Su domicilio de envío ha sido actualizado y establecido como principal.');
END;
$$ LANGUAGE plpgsql;


-- ██████████████████████████████████████████████████████████
-- ██  SECCIÓN 2: RESEÑAS / OPINIONES                      ██
-- ██████████████████████████████████████████████████████████
--
-- Las reseñas son "social proof" para generar confianza.
-- El listado es público (no requiere login).
-- Crear una reseña sí requiere sesión activa.


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 6: fn_reviews_list                             ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Proveer un feed de las opiniones más        ║
-- ║               influyentes para la Landing Page.         ║
-- ║  Llamada PHP: SELECT fn_reviews_list()                  ║
-- ║  Retorna    : JSON array [{id, calif, comment, user},...] ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Visitante carga la Landing Page (sin login).        ║
-- ║  2. PHP ejecuta SELECT fn_reviews_list().               ║
-- ║  3. JOIN con Usuarios resuelve nombres de autores.      ║
-- ║  4. LIMIT 10 + ORDER DESC para rendimiento y frescura.  ║
-- ║  5. Retorna JSON array → PHP renderiza el feed social.  ║
-- ║                                                         ║
-- ║  ACCESO PÚBLICO:                                        ║
-- ║  Función optimizada de solo lectura (STABLE) que no      ║
-- ║  requiere autenticación para su despliegue comercial.   ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE OR REPLACE FUNCTION fn_reviews_list()
RETURNS JSON
AS $$
DECLARE
    v_result JSON; -- Buffer de resultados
BEGIN
    -- Captura de las 10 reseñas más recientes con resolución de nombres.
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_result FROM (
        SELECT
            o.id_opinion,        -- Identificador de la reseña
            o.calificacion,      -- Escala de 1 a 5
            o.comentario,        -- Texto del testimonio
            o.fecha_opinion,     -- Fecha de publicación
            u.nom_usuario        -- Nombre del autor (vía JOIN)
        FROM tab_Opiniones o
        JOIN tab_Usuarios u ON o.id_usuario = u.id_usuario -- Nexo con el autor
        ORDER BY o.fecha_opinion DESC -- Prioridad cronológica inversa
        LIMIT 10 -- Cuantificación para rendimiento del frontend
    ) t;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 7: fn_reviews_check_dup                        ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Detectar intentos de duplicidad en la        ║
-- ║               publicación de testimonios.                ║
-- ║  Llamada PHP: SELECT fn_reviews_check_dup(user, 'Ok')   ║
-- ║  Retorna    : BOOLEAN (TRUE = Colisión detectada)        ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Cliente envía reseña desde el formulario.           ║
-- ║  2. PHP ejecuta fn_reviews_check_dup(user, texto) ANTES.║
-- ║  3. Si TRUE → PHP bloquea la publicación duplicada.     ║
-- ║  4. Si FALSE → PHP procede con fn_reviews_create.       ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_reviews_check_dup(
    p_user_id    tab_Usuarios.id_usuario%TYPE, -- El autor del comentario
    p_comentario tab_Opiniones.comentario%TYPE    -- El cuerpo del mensaje
)
RETURNS BOOLEAN
AS $$
BEGIN
    -- Verificación de existencia para gatekeeping de comentarios.
    RETURN EXISTS (
        SELECT 1 FROM tab_Opiniones
        WHERE id_usuario = p_user_id AND comentario = p_comentario
    );
END;
$$ LANGUAGE plpgsql STABLE;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 8: fn_reviews_create                           ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Registrar formalmente la opinión de un       ║
-- ║               cliente sobre la plataforma.               ║
-- ║  Llamada PHP: SELECT fn_reviews_create(user, 5, 'Msg')  ║
-- ║  Retorna    : JSON {ok: bool, msg, id_opinion}          ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Cliente llena formulario de reseña (estrellas+texto).║
-- ║  2. PHP (ya validó anti-dup) ejecuta fn_reviews_create. ║
-- ║  3. Valida rango estelar (1-5) y duplicidad.            ║
-- ║  4. Si válido → INSERT en tab_Opiniones.                ║
-- ║  5. Retorna {ok, msg, id} → PHP confirma al cliente.    ║
-- ║                                                         ║
-- ║  VALIDACIONES DE NEGOCIO:                                ║
-- ║  1. Rango Estelar: Solo se permiten de 1 a 5 estrellas.  ║
-- ║  2. Doble Publicación: Bloqueo de comentarios idénticos.║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_reviews_create(
    p_user_id     tab_Usuarios.id_usuario%TYPE,   -- Identidad del autor
    p_calificacion tab_Opiniones.calificacion%TYPE, -- Escala numérica de satisfacción
    p_comentario   tab_Opiniones.comentario%TYPE      -- Contenido narrativo
)
RETURNS JSON
AS $$
DECLARE
    v_new_id tab_Opiniones.id_opinion%TYPE; -- Recipiente para la nueva PK
BEGIN
    -- PASO 1: Validación de integridad sobre la escala estelar.
    IF p_calificacion < 1 OR p_calificacion > 5 THEN
        RETURN json_build_object('ok', false,
            'msg', 'Rango inválido: La experiencia debe calificarse entre 1 y 5 estrellas.');
    END IF;

    -- PASO 2: Gatekeeping contra el contenido redundante.
    IF EXISTS (SELECT 1 FROM tab_Opiniones WHERE id_usuario = p_user_id AND comentario = p_comentario) THEN
        RETURN json_build_object('ok', false,
            'msg', 'Bloqueo: El sistema detectó que ya has compartido esta opinión previamente.');
    END IF;

    -- PASO 3: Generación de identificador secuencial.
    -- LOCK previene condición de carrera en generación concurrente de IDs.
    LOCK TABLE tab_Opiniones IN EXCLUSIVE MODE;
    SELECT COALESCE(MAX(o.id_opinion), 0) + 1 INTO v_new_id FROM tab_Opiniones o;

    -- PASO 4: Inserción atómica del testimonio.
    INSERT INTO tab_Opiniones (
        id_opinion, 
        id_usuario, 
        id_producto, 
        calificacion, 
        comentario, 
        fecha_opinion, 
        fec_insert, 
        usr_insert
    ) VALUES (
        v_new_id, 
        p_user_id, 
        NULL, -- El 'site-review' general no se vincula a un producto específico
        p_calificacion, 
        p_comentario, 
        NOW(), 
        NOW(), 
        'web_customer_review'
    );

    RETURN json_build_object(
        'ok', true,
        'msg', 'Aportación exitosa: Tu reseña ha sido integrada a nuestro feed público.',
        'id_opinion', v_new_id
    );
END;
$$ LANGUAGE plpgsql;


-- ██████████████████████████████████████████████████████████
-- ██  SECCIÓN 3: CATÁLOGO GEOGRÁFICO                      ██
-- ██████████████████████████████████████████████████████████
--
-- Dropdown de departamentos → ciudades para checkout
-- y panel de dirección del usuario.


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 9: fn_geo_departamentos                        ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Suministrar el primer nivel de la jerarquía  ║
-- ║               geográfica (Niveles territoriales).       ║
-- ║  Llamada PHP: SELECT fn_geo_departamentos()             ║
-- ║  Retorna    : JSON array [{id_depto, nom_depto}, ...]   ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Cliente abre selector de dirección.                 ║
-- ║  2. PHP ejecuta SELECT fn_geo_departamentos().          ║
-- ║  3. Retorna JSON array → JS pobla el dropdown padre.    ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE OR REPLACE FUNCTION fn_geo_departamentos()
RETURNS JSON
AS $$
DECLARE
    v_result JSON; -- Buffer de salida
BEGIN
    -- Selección lexicográfica de departamentos para facilitar la búsqueda UI.
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_result FROM (
        SELECT 
            d.id_departamento, 
            d.nombre_departamento
        FROM tab_Departamentos d
        ORDER BY d.nombre_departamento ASC -- Orden alfabético mandatorio
    ) t;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 10: fn_geo_ciudades                            ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Resolver el segundo nivel jerárquico        ║
-- ║               geográfico filtrado por pertenencia.      ║
-- ║  Llamada PHP: SELECT fn_geo_ciudades(5)                 ║
-- ║  Retorna    : JSON array [{id_ciudad, nombre, cp}, ...] ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Cliente selecciona un departamento en el dropdown.  ║
-- ║  2. JS dispara AJAX → PHP ejecuta fn_geo_ciudades(id).  ║
-- ║  3. WHERE filtra por pertenencia territorial.           ║
-- ║  4. Retorna JSON array → JS pobla el dropdown hijo.     ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE OR REPLACE FUNCTION fn_geo_ciudades(
    p_depto_id tab_Departamentos.id_departamento%TYPE -- Filtro de dependencia territorial
)
RETURNS JSON
AS $$
DECLARE
    v_result JSON; -- Buffer de salida
BEGIN
    -- Filtrado reactivo de ciudades pertenecientes al nodo padre.
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_result FROM (
        SELECT 
            c.id_ciudad, 
            c.nombre_ciudad, 
            c.codigo_postal
        FROM tab_Ciudades c
        WHERE c.id_departamento = p_depto_id -- Filtro de jerarquía
        ORDER BY c.nombre_ciudad ASC -- Orden alfabético para el SELECT
    ) t;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE;


-- ██████████████████████████████████████████████████████████
-- ██  SECCIÓN 4: ADMINISTRACIÓN DE CLIENTES               ██
-- ██████████████████████████████████████████████████████████
--
-- Solo admin puede ver la lista de clientes y cambiar
-- su estado activo/inactivo. Nunca expone contraseñas.


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 11: fn_admin_list_clients                      ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Extraer el censo completo de clientes para    ║
-- ║               la consola de administración.              ║
-- ║  Llamada PHP: SELECT fn_admin_list_clients()            ║
-- ║  Retorna    : JSON array [{id, nom, correo, activo},...]║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin abre la sección "Clientes" del panel.         ║
-- ║  2. PHP ejecuta SELECT fn_admin_list_clients().         ║
-- ║  3. WHERE filtra solo rol='cliente' (protege admins).   ║
-- ║  4. Retorna JSON array → PHP renderiza tabla de clientes.║
-- ║                                                         ║
-- ║  ESTRICTO:                                              ║
-- ║  Filtra solo usuarios con rol 'cliente', protegiendo a   ║
-- ║  los administradores de aparecer en listados comunes.   ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE OR REPLACE FUNCTION fn_admin_list_clients()
RETURNS JSON
AS $$
DECLARE
    v_result JSON; -- Buffer de salida
BEGIN
    -- Compilación de perfiles con exclusión de credenciales críticas.
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_result FROM (
        SELECT
            u.id_usuario,
            u.nom_usuario,
            u.correo_usuario,
            u.num_telefono_usuario,
            u.activo,
            u.fecha_registro
        FROM tab_Usuarios u
        WHERE u.rol = 'cliente' -- Segregación de roles lógica
        ORDER BY u.id_usuario DESC -- Novedad incremental
    ) t;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 12: fn_admin_check_role                        ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Resolver la identidad de rol de un usuario   ║
-- ║               antes de autorizar acciones críticas.      ║
-- ║  Llamada PHP: SELECT fn_admin_check_role(123)           ║
-- ║  Retorna    : TEXT ('admin' | 'cliente' | NULL)         ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. PHP necesita verificar rol antes de una acción.     ║
-- ║  2. Ejecuta SELECT fn_admin_check_role(target_id).      ║
-- ║  3. Retorna TEXT → PHP decide si autorizar la operación.║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_admin_check_role(
    p_target_id tab_Usuarios.id_usuario%TYPE -- ID del usuario a consultar
)
RETURNS TEXT 
AS $$
DECLARE
    v_rol tab_Usuarios.rol%TYPE; -- Escalar de rol
BEGIN
    -- Consulta rápida al maestro de usuarios.
    SELECT u.rol INTO v_rol
    FROM tab_Usuarios u
    WHERE u.id_usuario = p_target_id;

    RETURN v_rol;
END;
$$ LANGUAGE plpgsql STABLE;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 13: fn_admin_toggle_client                     ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Inhabilitar o reactivar el acceso de un      ║
-- ║               cliente al ecosistema comercial.           ║
-- ║  Llamada PHP: SELECT fn_admin_toggle_client(123, FALSE) ║
-- ║  Retorna    : JSON {ok: bool, msg: text}                ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin pulsa Activar/Desactivar en la tabla.         ║
-- ║  2. PHP ejecuta fn_admin_toggle_client(id, estado).     ║
-- ║  3. Verifica existencia y que NO sea admin.             ║
-- ║  4. Si cliente → UPDATE estado con sello de auditoría.  ║
-- ║  5. Retorna {ok, msg} → PHP confirma al admin.          ║
-- ║                                                         ║
-- ║  BARRERA DE SEGURIDAD:                                   ║
-- ║  La función detecta si se intenta modificar a un admin   ║
-- ║  y BLOQUEA la acción para evitar auto-exclusiones o      ║
-- ║  vulnerabilidades de escalación.                         ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_admin_toggle_client(
    p_target_id  tab_Usuarios.id_usuario%TYPE,    -- El usuario a Intervention
    p_new_state  tab_Usuarios.activo%TYPE    -- Estado bit (TRUE/FALSE)
)
RETURNS JSON
AS $$
DECLARE
    v_rol tab_Usuarios.rol%TYPE; -- Verificador de privilegios
BEGIN
    -- Verificación preventiva de existencia y jerarquía.
    SELECT u.rol INTO v_rol FROM tab_Usuarios u WHERE u.id_usuario = p_target_id;

    IF v_rol IS NULL THEN
        RETURN json_build_object('ok', false, 'msg', 'Identidad nula: El usuario indicado no existe.');
    END IF;

    -- PROTECCIÓN: Los administradores son inmunes a esta función.
    IF v_rol <> 'cliente' THEN
        RETURN json_build_object('ok', false,
            'msg', 'Privilegios insuficientes: No está permitido alternar el estado de cuentas administrativas.');
    END IF;

    -- DML: Alteración del estado con firma de auditoría administrativa.
    UPDATE tab_Usuarios
    SET activo = p_new_state, 
        fec_update = NOW(), 
        usr_update = 'admin_mgmt_kernel'
    WHERE id_usuario = p_target_id;

    RETURN json_build_object('ok', true, 'msg', 'El estado del usuario ha sido recalibrado exitosamente.');
END;
$$ LANGUAGE plpgsql;


-- ██████████████████████████████████████████████████████████
-- ██  SECCIÓN 5: CONFIGURACIÓN GLOBAL (Admin Settings)    ██
-- ██████████████████████████████████████████████████████████
--
-- Actualmente devuelve datos estáticos (mock).
-- Preparado para futura tabla tab_Configuracion.


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 14: fn_admin_get_settings                      ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Proveer los metadatos globales de la tienda  ║
-- ║               y del entorno operativo.                  ║
-- ║  Llamada PHP: SELECT fn_admin_get_settings()            ║
-- ║  Retorna    : JSON {store: {...}, admin: {...}}         ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin abre la sección "Configuración" del panel.    ║
-- ║  2. PHP ejecuta SELECT fn_admin_get_settings().         ║
-- ║  3. Retorna JSON estático → PHP renderiza formulario.    ║
-- ║                                                         ║
-- ║  NOTA DE ARQUITECTURA:                                   ║
-- ║  Esta función actúa como un MOCK estructurado. Los datos ║
-- ║  están hardcodeados para asegurar la estabilidad del UI  ║
-- ║  mientras se integra la tabla 'tab_Configuracion'.       ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE OR REPLACE FUNCTION fn_admin_get_settings()
RETURNS JSON
AS $$
DECLARE
    v_nombre_tienda tab_Configuracion.valor%TYPE;
    v_moneda        tab_Configuracion.valor%TYPE;
    v_tasa          NUMERIC;
    v_admin_nombre  tab_Usuarios.nom_usuario%TYPE;
BEGIN
    SELECT valor INTO v_nombre_tienda FROM tab_Configuracion WHERE clave = 'nombre_tienda';
    SELECT valor INTO v_moneda        FROM tab_Configuracion WHERE clave = 'moneda';
    SELECT CAST(valor AS NUMERIC) INTO v_tasa FROM tab_Configuracion WHERE clave = 'tasa_cambio';

    SELECT nom_usuario INTO v_admin_nombre
    FROM tab_Usuarios
    WHERE rol = 'admin'
    ORDER BY id_usuario
    LIMIT 1;

    RETURN json_build_object(
        'store', json_build_object(
            'nombre',      COALESCE(v_nombre_tienda, 'RD-Watch'),
            'moneda',      COALESCE(v_moneda, 'COP'),
            'tasa_cambio', COALESCE(v_tasa, 1)
        ),
        'admin', json_build_object(
            'usuario', COALESCE(v_admin_nombre, 'admin')
        )
    );
END;
$$ LANGUAGE plpgsql STABLE;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 15: fn_admin_get_stats                         ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Generar una vista consolidada de los KPIs   ║
-- ║               críticos del ecosistema (Vanguardia).      ║
-- ║  Llamada PHP: SELECT fn_admin_get_stats()               ║
-- ║  Retorna    : JSON {total_clientes, total_pedidos, ...} ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin carga el dashboard de configuración.          ║
-- ║  2. PHP ejecuta SELECT fn_admin_get_stats().            ║
-- ║  3. 3 conteos paralelos (clientes, pedidos, productos). ║
-- ║  4. Retorna JSON → PHP renderiza tarjetas de KPIs.      ║
-- ║                                                         ║
-- ║  FLUJO DE CONTEO:                                        ║
-- ║  Escanea en paralelo las tablas maestras para entregar   ║
-- ║  una respuesta atómica de volumen de datos.              ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE OR REPLACE FUNCTION fn_admin_get_stats()
RETURNS JSON
AS $$
DECLARE
    v_total_clients  INTEGER; -- Volumen de clientes registrados
    v_total_orders   INTEGER; -- Tráfico histórico de pedidos
    v_total_products INTEGER; -- Amplitud del catálogo activo
BEGIN
    -- Ejecución de selectores de volumen ponderado.
    SELECT COUNT(u.id_usuario) INTO v_total_clients FROM tab_Usuarios u WHERE u.rol = 'cliente';
    SELECT COUNT(o.id_orden) INTO v_total_orders FROM tab_Orden o;
    SELECT COUNT(p.id_producto) INTO v_total_products FROM tab_Productos p;

    -- Consolidación de métricas en objeto de transporte.
    RETURN json_build_object(
        'total_clientes', v_total_clients,
        'total_pedidos', v_total_orders,
        'total_productos', v_total_products
    );
END;
$$ LANGUAGE plpgsql STABLE;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 16: fn_admin_update_settings                   ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Endpoint para la persistencia de cambios en ║
-- ║               la configuración global.                   ║
-- ║  Llamada PHP: SELECT fn_admin_update_settings(json)     ║
-- ║  Retorna    : JSON {ok: true, msg: text}                ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin modifica campos en el formulario de config.   ║
-- ║  2. PHP ejecuta fn_admin_update_settings(json_data).    ║
-- ║  3. Actualmente MOCK: retorna éxito sin mutar la DB.    ║
-- ║  4. Retorna {ok, msg} → PHP confirma al admin.          ║
-- ║                                                         ║
-- ║  NOTA:                                                  ║
-- ║  Actualmente simulada. Retorna éxito para permitir el    ║
-- ║  testeo de flujos en el frontend sin mutar la DB.       ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE OR REPLACE FUNCTION fn_admin_update_settings(
    p_data JSON
)
RETURNS JSON
AS $$
DECLARE
    v_moneda      tab_Configuracion.valor%TYPE;
    v_tasa        NUMERIC;
BEGIN
    v_moneda := trim(p_data->>'moneda');
    v_tasa   := CAST(NULLIF(trim(p_data->>'tasa_cambio'), '') AS NUMERIC);

    IF v_moneda IS NULL OR v_moneda = '' THEN
        RETURN json_build_object('ok', false, 'msg', 'Debe seleccionar una moneda válida');
    END IF;

    -- Guardar moneda
    INSERT INTO tab_Configuracion (clave, valor, usr_insert, fec_insert)
    VALUES ('moneda', v_moneda, 'admin', NOW())
    ON CONFLICT (clave) DO UPDATE
        SET valor = EXCLUDED.valor, usr_update = 'admin', fec_update = NOW();

    -- Guardar tasa de cambio si viene
    IF v_tasa IS NOT NULL AND v_tasa > 0 THEN
        INSERT INTO tab_Configuracion (clave, valor, usr_insert, fec_insert)
        VALUES ('tasa_cambio', CAST(v_tasa AS TEXT), 'admin', NOW())
        ON CONFLICT (clave) DO UPDATE
            SET valor = EXCLUDED.valor, usr_update = 'admin', fec_update = NOW();
    END IF;

    RETURN json_build_object('ok', true, 'msg', 'Moneda actualizada correctamente');
END;
$$ LANGUAGE plpgsql;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 17: fn_admin_change_password                   ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Obtener la contraseña hash del admin para   ║
-- ║               que PHP la valide y actualice si es correcta. ║
-- ║  Retorna    : JSON con ok, hash_actual para verificación   ║
-- ║               y acción de update si es requerida.         ║
-- ║                                                           ║
-- ║  FLUJO:                                                   ║
-- ║  1. PHP llama fn_admin_get_hash(id_usuario)              ║
-- ║  2. PHP verifica con password_verify(current, hash)      ║
-- ║  3. Si ok → PHP genera nuevo hash y llama                ║
-- ║     fn_admin_set_password(id_usuario, nuevo_hash)        ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_admin_get_hash(
    p_id_usuario tab_Usuarios.id_usuario%TYPE
)
RETURNS TEXT
AS $$
BEGIN
    RETURN (
        SELECT contra
        FROM tab_Usuarios
        WHERE id_usuario = p_id_usuario AND rol = 'admin'
    );
END;
$$ LANGUAGE plpgsql STABLE;


CREATE OR REPLACE FUNCTION fn_admin_set_password(
    p_id_usuario tab_Usuarios.id_usuario%TYPE,
    p_nuevo_hash tab_Usuarios.contra%TYPE
)
RETURNS JSON
AS $$
BEGIN
    UPDATE tab_Usuarios
    SET contra = p_nuevo_hash,
        usr_update = 'admin',
        fec_update = NOW()
    WHERE id_usuario = p_id_usuario AND rol = 'admin';

    IF NOT FOUND THEN
        RETURN json_build_object('ok', false, 'msg', 'No se encontró el administrador');
    END IF;

    RETURN json_build_object('ok', true, 'msg', 'Contraseña actualizada correctamente');
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION fn_admin_update_nombre(
    p_id_usuario tab_Usuarios.id_usuario%TYPE,
    p_nuevo_nombre tab_Usuarios.nom_usuario%TYPE
)
RETURNS JSON
AS $$
BEGIN
    IF trim(p_nuevo_nombre) = '' THEN
        RETURN json_build_object('ok', false, 'msg', 'El nombre de usuario no puede estar vacío');
    END IF;

    UPDATE tab_Usuarios
    SET nom_usuario = trim(p_nuevo_nombre),
        usr_update = 'admin',
        fec_update = NOW()
    WHERE id_usuario = p_id_usuario AND rol = 'admin';

    IF NOT FOUND THEN
        RETURN json_build_object('ok', false, 'msg', 'Administrador no encontrado');
    END IF;

    RETURN json_build_object('ok', true, 'msg', 'Nombre de usuario actualizado correctamente');
END;
$$ LANGUAGE plpgsql;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN: fn_contacto_list_admin                        ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Exponer al administrador todas las          ║
-- ║               solicitudes enviadas desde el formulario  ║
-- ║               de contacto de la página principal.        ║
-- ║  Llamada PHP: SELECT fn_contacto_list_admin()           ║
-- ║  Retorna    : JSON array [{id_contacto, nombre_remitente,║
-- ║               correo_remitente, telefono_remitente,      ║
-- ║               mensaje, fecha_envio, estado}, ...]        ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin abre la sección "Citas" del panel.            ║
-- ║  2. PHP ejecuta SELECT fn_contacto_list_admin().        ║
-- ║  3. Frontend muestra los mensajes junto a las citas.    ║
-- ║                                                         ║
-- ║  NOTA: No altera la estructura de tab_contacto.         ║
-- ║  Solo lectura (STABLE). Acceso exclusivo de admin.      ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_contacto_list_admin()
RETURNS JSON
AS $$
DECLARE
    v_result JSON; -- Buffer de solicitudes de contacto
BEGIN
    -- Compilación cronológica inversa de todos los mensajes del formulario público.
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_result FROM (
        SELECT
            c.id_contacto,          -- PK del mensaje
            c.nombre_remitente,     -- Nombre del visitante
            c.correo_remitente,     -- Email de contacto
            c.telefono_remitente,   -- Teléfono de contacto
            c.mensaje,              -- Cuerpo del mensaje
            c.fecha_envio,          -- Instante de recepción
            c.estado                -- Estado actual (pendiente/atendido)
        FROM tab_contacto c
        ORDER BY c.fecha_envio DESC -- Más recientes primero
    ) t;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE;
