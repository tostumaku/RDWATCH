-- ============================================================
-- MÓDULO: SEGURIDAD Y ACCESO (auth_security.sql)
-- ============================================================
-- Fase        : 1 de 5 — Seguridad y Autenticación
-- ============================================================

-- FUNCIONES EN ESTE MÓDULO (9 total):
-- ────────────────────────────────────
-- 1. fn_auth_get_user         → Busca un usuario por email para login
-- 2. fn_auth_update_hash      → Migra contraseña plana a bcrypt
-- 3. fn_auth_register         → Registra un nuevo usuario
-- 4. fn_auth_forgot_password  → Genera token de recuperación
-- 5. fn_auth_reset_password   → Aplica nueva contraseña con token
-- 6. fn_auth_get_session      → Obtiene datos del usuario logueado
-- 7. fn_sec_check_rate_limit  → Verifica intentos fallidos (anti-brute force)
-- 8. fn_sec_log_attempt       → Registra un intento fallido
-- 9. fn_sec_clear_attempts    → Limpia intentos tras login exitoso
--
-- TABLAS QUE ESTE MÓDULO TOCA (pero PHP no lo sabe):
-- ────────────────────────────────────
-- tab_Usuarios        → Cuentas de usuario (login, perfil)
-- tab_Rate_Limits     → Registro de intentos fallidos
-- tab_Direcciones_Envio → Direcciones de envío del usuario
-- tab_Ciudades        → Catálogo de ciudades
-- ============================================================


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 1: fn_auth_get_user                            ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Buscar un usuario por su correo para      ║
-- ║               el proceso de login.                      ║
-- ║  Llamada PHP: SELECT fn_auth_get_user('email@test.com') ║
-- ║  Retorna    : JSON con datos del usuario o NULL si      ║
-- ║               no existe.                                ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. PHP envía el email del usuario                      ║
-- ║  2. La función busca en tab_Usuarios por correo         ║
-- ║  3. Retorna JSON con: id, nombre, hash de contraseña,   ║
-- ║     rol, si está activo, si está bloqueado               ║
-- ║  4. PHP usa el hash para verificar con password_verify  ║
-- ║                                                         ║
-- ║  ¿Por qué retorna 'contra' (el hash)?                  ║
-- ║  Porque PHP necesita comparar la contraseña ingresada   ║
-- ║  contra el hash almacenado usando password_verify().    ║
-- ║  Esto es seguro porque el hash viaja dentro de JSON     ║
-- ║  en memoria del servidor, nunca al cliente.             ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_auth_get_user(
    p_email tab_Usuarios.correo_usuario%TYPE  -- El correo electrónico que el usuario escribió en el formulario de login
)
RETURNS JSON  -- Retorna UN objeto JSON (no una tabla), PHP hace json_decode()
AS $$
DECLARE
    v_result JSON;  -- Variable donde guardamos el JSON construido
BEGIN
    -- row_to_json(t) convierte UNA fila completa en un objeto JSON
    -- La subconsulta "t" selecciona exactamente las columnas que necesitamos
    SELECT row_to_json(t) INTO v_result FROM (
        SELECT
            u.id_usuario,   -- ID numérico del usuario (INTEGER)
            u.nom_usuario,  -- Nombre completo del usuario
            u.contra,       -- Hash bcrypt de la contraseña (PHP lo necesita para password_verify)
            u.rol,          -- 'admin' o 'cliente' (controla acceso a funciones admin)
            u.activo,       -- TRUE si la cuenta está habilitada
            u.bloqueado     -- TRUE si fue bloqueado por seguridad
        FROM tab_Usuarios u
        WHERE u.correo_usuario = p_email  -- Busca por email exacto (case sensitive)
    ) t;

    -- Si no encontró usuario, v_result será NULL
    -- PHP interpreta NULL como "usuario no encontrado"
    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE;
-- STABLE = indica a PostgreSQL que esta función no modifica datos,
-- solo lee. Esto permite optimizaciones de caché del motor.


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 2: fn_auth_update_hash                         ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Actualizar la contraseña de un usuario    ║
-- ║               cuando se detecta que tiene formato       ║
-- ║               legacy (texto plano) en vez de bcrypt.    ║
-- ║  Llamada PHP: SELECT fn_auth_update_hash(123, '$2b$...') ║
-- ║  Retorna    : VOID (no devuelve nada)                   ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Durante el login, si password_verify falla pero     ║
-- ║     la contraseña coincide en texto plano, PHP detecta  ║
-- ║     que es una contraseña legacy                        ║
-- ║  2. PHP genera el hash bcrypt nuevo                     ║
-- ║  3. Llama esta función para actualizar el hash          ║
-- ║  4. El usuario no nota nada, su próximo login usará     ║
-- ║     bcrypt automáticamente                              ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_auth_update_hash(
    p_uid      tab_Usuarios.id_usuario%TYPE,  -- ID del usuario cuya contraseña se actualiza
    p_new_hash tab_Usuarios.contra%TYPE     -- Nuevo hash bcrypt generado por PHP con password_hash()
)
RETURNS VOID  -- No retorna nada, solo actualiza
AS $$
BEGIN
    UPDATE tab_Usuarios
    SET contra = p_new_hash,                     -- Reemplaza la contraseña plana por el hash bcrypt
        fec_update = NOW(),                      -- Marca la fecha de actualización (auditoría)
        usr_update = 'system_hash_migration'     -- Identifica que fue una migración automática
    WHERE id_usuario = p_uid;
END;
$$ LANGUAGE plpgsql;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 3: fn_auth_register                            ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Registrar un nuevo usuario en el sistema. ║
-- ║  Llamada PHP: SELECT fn_auth_register('Juan', ...)      ║
-- ║  Retorna    : JSON con {ok: true/false, msg: '...'}     ║
-- ║                                                         ║
-- ║  VALIDACIONES INTERNAS:                                 ║
-- ║  1. Verifica que el email no esté ya registrado         ║
-- ║  2. Verifica que no exista la combinación nombre+tel    ║
-- ║  3. Auto-genera el siguiente ID (MAX + 1)              ║
-- ║  4. Inserta con rol='cliente', activo=TRUE              ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. PHP valida el formato del input (email, nombre...)  ║
-- ║  2. PHP genera el hash bcrypt de la contraseña          ║
-- ║  3. Llama esta función con los 4 parámetros             ║
-- ║  4. La función hace las validaciones de duplicados      ║
-- ║  5. Si todo ok, inserta y retorna {ok: true}            ║
-- ║  6. Si hay duplicado, retorna {ok: false, msg: '...'}   ║
-- ║  7. PHP simplemente reenvía el JSON al frontend         ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_auth_register(
    p_nombre    tab_Usuarios.nom_usuario%TYPE,  -- Nombre completo del usuario
    p_email     tab_Usuarios.correo_usuario%TYPE,  -- Correo electrónico (debe ser único)
    p_telefono  TEXT,  -- Número de teléfono (se convierte a BIGINT internamente, llega como TEXT desde PHP)
    p_hash      tab_Usuarios.contra%TYPE   -- Hash bcrypt ya generado por PHP (NUNCA la contraseña en texto plano)
)
RETURNS JSON  -- Siempre retorna {ok: bool, msg: string}
AS $$
DECLARE
    v_new_id tab_Usuarios.id_usuario%TYPE;  -- ID que se asignará al nuevo usuario
BEGIN
    -- VALIDACIÓN 1: ¿El email ya existe?
    -- Si alguien ya se registró con este correo, bloqueamos
    IF EXISTS (SELECT 1 FROM tab_Usuarios WHERE correo_usuario = p_email) THEN
        RETURN json_build_object(
            'ok', false,
            'msg', 'Inconsistencia: Esta dirección de correo electrónico ya posee una cuenta activa'
        );
    END IF;

    -- VALIDACIÓN 2: ¿Existe la misma combinación nombre + teléfono?
    -- Esto previene registros duplicados con diferentes emails
    IF EXISTS (SELECT 1 FROM tab_Usuarios WHERE nom_usuario = p_nombre AND num_telefono_usuario = p_telefono::BIGINT) THEN
        RETURN json_build_object(
            'ok', false,
            'msg', 'Inconsistencia: Ya existe un registro con esta combinación de nombre y teléfono.'
        );
    END IF;

    -- AUTO-GENERAR ID: Obtiene el máximo ID actual y suma 1
    -- COALESCE maneja el caso de tabla vacía (retorna 0 si no hay registros)
    SELECT COALESCE(MAX(u.id_usuario), 0) + 1 INTO v_new_id FROM tab_Usuarios u;

    -- INSERCIÓN: Crea el nuevo usuario con valores por defecto seguros
    INSERT INTO tab_Usuarios (
        id_usuario,              -- ID auto-generado
        nom_usuario,             -- Nombre proporcionado
        correo_usuario,          -- Email proporcionado
        num_telefono_usuario,    -- Teléfono convertido a BIGINT
        contra,                  -- Hash bcrypt (NUNCA texto plano)
        salt,                    -- Campo legacy, se mantiene por compatibilidad
        rol,                     -- Siempre 'cliente' para autoregistro
        activo,                  -- Cuenta habilitada desde el inicio
        bloqueado,               -- No bloqueado por defecto
        fecha_registro,          -- Timestamp del momento de registro
        intentos_fallidos        -- Comienza en 0
    ) VALUES (
        v_new_id, p_nombre, p_email, p_telefono::BIGINT,
        p_hash, 'legacy_salt', 'cliente', TRUE, FALSE, NOW(), 0
    );

    -- RESPUESTA EXITOSA: Incluye el nombre del usuario en el mensaje de bienvenida
    RETURN json_build_object(
        'ok', true,
        'msg', '¡Bienvenido a RD-Watch, ' || p_nombre || '! Tu cuenta ha sido creada exitosamente. Ya puedes iniciar sesión.'
    );
END;
$$ LANGUAGE plpgsql;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 4: fn_auth_forgot_password                     ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Procesar solicitud de recuperación de     ║
-- ║               contraseña. Genera y guarda un token      ║
-- ║               temporal.                                 ║
-- ║  Llamada PHP: SELECT fn_auth_forgot_password(           ║
-- ║                 'email', 'token_hex', '2026-02-20...')   ║
-- ║  Retorna    : JSON con datos del usuario o NULL si      ║
-- ║               el email no existe (por seguridad,        ║
-- ║               PHP no revela si el email existe o no     ║
-- ║               al frontend).                             ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. PHP genera un token aleatorio con bin2hex(random_bytes) ║
-- ║  2. PHP calcula la fecha de expiración (+1 hora)        ║
-- ║  3. Llama esta función con email, token y expiración    ║
-- ║  4. La función verifica que el email exista y esté activo║
-- ║  5. Si existe: guarda el token en la BD, retorna JSON   ║
-- ║  6. Si no existe: retorna NULL                          ║
-- ║  7. PHP envía mensaje genérico al frontend (no revela   ║
-- ║     si el email existe o no — protección anti-enumerar) ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_auth_forgot_password(
    p_email   tab_Usuarios.correo_usuario%TYPE,       -- Email del usuario que solicita recuperación
    p_token   tab_Usuarios.token_recuperacion%TYPE,       -- Token aleatorio de 64 caracteres (generado por PHP)
    p_expires tab_Usuarios.token_expiracion%TYPE   -- Fecha y hora de expiración del token
)
RETURNS JSON  -- JSON con id y nombre del usuario, o NULL si no existe
AS $$
DECLARE
    v_result JSON;
BEGIN
    -- VERIFICACIÓN: ¿Existe un usuario activo con este email?
    -- Si no existe, retornamos NULL (PHP muestra mensaje genérico)
    IF NOT EXISTS (SELECT 1 FROM tab_Usuarios u WHERE u.correo_usuario = p_email AND u.activo = TRUE) THEN
        RETURN NULL;
    END IF;

    -- ACTUALIZACIÓN: Guarda el token y su fecha de expiración en la BD
    -- Estos campos se usarán después en fn_auth_reset_password
    UPDATE tab_Usuarios
    SET token_recuperacion = p_token,        -- Token que se enviará por email al usuario
        token_expiracion = p_expires,        -- Cuándo deja de ser válido
        fec_update = NOW(),                  -- Auditoría: cuándo se modificó
        usr_update = 'system_recovery'       -- Auditoría: quién/qué lo modificó
    WHERE correo_usuario = p_email AND activo = TRUE;

    -- RETORNO: Solo el ID y nombre (PHP los necesita para el email de recuperación)
    SELECT row_to_json(t) INTO v_result FROM (
        SELECT u.id_usuario, u.nom_usuario
        FROM tab_Usuarios u
        WHERE u.correo_usuario = p_email AND u.activo = TRUE
    ) t;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 5: fn_auth_reset_password                      ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Aplicar nueva contraseña usando el token  ║
-- ║               de recuperación.                          ║
-- ║  Llamada PHP: SELECT fn_auth_reset_password('token',    ║
-- ║                 '$2b$12$...')                            ║
-- ║  Retorna    : JSON con {ok: true/false, msg: '...'}     ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. El usuario hace clic en el enlace de recuperación   ║
-- ║  2. PHP recibe el token de la URL y la nueva contraseña ║
-- ║  3. PHP genera el hash bcrypt de la nueva contraseña    ║
-- ║  4. Llama esta función con token y hash                 ║
-- ║  5. La función busca un usuario con ese token           ║
-- ║     Y verifica que no haya expirado (token_expiracion > NOW()) ║
-- ║  6. Si el token es válido: actualiza contraseña y limpia token ║
-- ║  7. Si no: retorna error                                ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_auth_reset_password(
    p_token    tab_Usuarios.token_recuperacion%TYPE,  -- Token de 64 caracteres que vino en la URL
    p_new_hash tab_Usuarios.contra%TYPE   -- Hash bcrypt de la nueva contraseña (generado por PHP)
)
RETURNS JSON  -- Siempre retorna {ok: bool, msg: string}
AS $$
DECLARE
    v_uid tab_Usuarios.id_usuario%TYPE;  -- ID del usuario que posee este token
BEGIN
    -- BÚSQUEDA: ¿Existe un usuario con este token que NO haya expirado?
    -- NOW() = fecha y hora actual del servidor
    SELECT u.id_usuario INTO v_uid
    FROM tab_Usuarios u
    WHERE u.token_recuperacion = p_token    -- Coincide el token
      AND u.token_expiracion > NOW();       -- Y aún no ha expirado

    -- Si no encontró usuario (token inválido o expirado)
    IF v_uid IS NULL THEN
        RETURN json_build_object(
            'ok', false,
            'msg', 'El enlace ha expirado o no es válido. Por favor solicita uno nuevo.'
        );
    END IF;

    -- ACTUALIZACIÓN: Aplica nueva contraseña y limpia los campos de token
    UPDATE tab_Usuarios
    SET contra = p_new_hash,              -- Nueva contraseña hasheada
        token_recuperacion = NULL,         -- Limpia el token (uso único)
        token_expiracion = NULL,           -- Limpia la expiración
        fec_update = NOW(),               -- Auditoría
        usr_update = 'user_password_reset' -- Quién lo hizo
    WHERE id_usuario = v_uid;

    RETURN json_build_object(
        'ok', true,
        'msg', 'Tu contraseña ha sido actualizada exitosamente. Ya puedes iniciar sesión.'
    );
END;
$$ LANGUAGE plpgsql;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 6: fn_auth_get_session                         ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Obtener datos completos del usuario       ║
-- ║               logueado para el endpoint /api/me.php     ║
-- ║  Llamada PHP: SELECT fn_auth_get_session(123)           ║
-- ║  Retorna    : JSON con perfil completo del usuario,     ║
-- ║               incluyendo su dirección de envío          ║
-- ║               predeterminada y ciudad.                  ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. El frontend llama a /api/me.php para saber quién    ║
-- ║     está logueado                                       ║
-- ║  2. PHP toma el user_id de la sesión ($_SESSION)        ║
-- ║  3. Llama esta función con el ID                        ║
-- ║  4. La función hace un JOIN con direcciones y ciudades  ║
-- ║  5. Retorna JSON con toda la info del perfil            ║
-- ║  6. PHP arma la respuesta para el frontend              ║
-- ║                                                         ║
-- ║  JOINS INTERNOS:                                        ║
-- ║  tab_Usuarios → tab_Direcciones_Envio → tab_Ciudades    ║
-- ║  (LEFT JOIN porque un usuario puede no tener dirección) ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_auth_get_session(
    p_uid tab_Usuarios.id_usuario%TYPE  -- ID del usuario logueado (viene de $_SESSION['user_id'])
)
RETURNS JSON  -- JSON con perfil completo del usuario
AS $$
DECLARE
    v_result JSON;
BEGIN
    SELECT row_to_json(t) INTO v_result FROM (
        SELECT
            u.id_usuario,           -- ID del usuario
            u.nom_usuario,          -- Nombre completo
            u.rol,                  -- 'admin' o 'cliente'
            u.direccion_principal,  -- Dirección guardada en la tabla de usuarios
            -- Priorizamos la predeterminada; si no hay, devolvemos lo que haya en direccion_principal.
            COALESCE(d.direccion_completa, u.direccion_principal) as direccion_completa,
            c.nombre_ciudad         -- Nombre de la ciudad asociada
        FROM tab_Usuarios u
        -- LEFT JOIN: Buscamos la predeterminada en la agenda
        LEFT JOIN tab_Direcciones_Envio d
            ON u.id_usuario = d.id_usuario
            AND d.es_predeterminada = TRUE
        -- LEFT JOIN: Ciudad relacionada
        LEFT JOIN tab_Ciudades c
            ON d.id_ciudad = c.id_ciudad
        WHERE u.id_usuario = p_uid
        LIMIT 1
    ) t;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE;  -- STABLE porque solo lee datos


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 7: fn_sec_check_rate_limit                     ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Verificar si una IP ha excedido el        ║
-- ║               límite de intentos fallidos.              ║
-- ║               Protección contra ataques de fuerza bruta.║
-- ║  Llamada PHP: SELECT fn_sec_check_rate_limit(           ║
-- ║                 '192.168.1.1', 'login_attempt', 5, 15)  ║
-- ║  Retorna    : BOOLEAN                                   ║
-- ║               TRUE  = Puede intentar (no alcanzó límite)║
-- ║               FALSE = Bloqueado (demasiados intentos)   ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. PHP obtiene la IP del cliente                       ║
-- ║  2. Llama esta función antes de procesar el login       ║
-- ║  3. La función cuenta intentos en la ventana de tiempo  ║
-- ║  4. Si hay < 5 intentos en 15 min → TRUE (puede pasar) ║
-- ║  5. Si hay >= 5 intentos en 15 min → FALSE (bloqueado)  ║
-- ║  6. PHP muestra message de "espere 15 minutos" si FALSE ║
-- ║                                                         ║
-- ║  NOTA: Esta es la ÚNICA función que retorna BOOLEAN     ║
-- ║  en vez de JSON, porque es una verificación simple       ║
-- ║  de sí/no que no necesita estructura JSON.              ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE OR REPLACE FUNCTION fn_sec_check_rate_limit(
    p_ip     tab_Rate_Limits.identificador%TYPE,              -- Dirección IP del cliente
    p_action tab_Rate_Limits.nom_accion%TYPE,              -- Tipo de acción ('login_attempt', 'forgot_password', etc.)
    p_limit  INTEGER DEFAULT 5, -- Máximo de intentos permitidos (por defecto 5)
    p_window INTEGER DEFAULT 15 -- Ventana de tiempo en minutos (por defecto 15)
)
RETURNS BOOLEAN  -- TRUE = permitido, FALSE = bloqueado
AS $$
DECLARE
    v_count INTEGER;  -- Cantidad de intentos encontrados
BEGIN
    -- Contamos cuántos intentos hay para esta IP + acción
    -- dentro de la ventana de tiempo especificada
    SELECT COUNT(id_rate_limit) INTO v_count
    FROM tab_Rate_Limits
    WHERE identificador = p_ip           -- Misma IP
      AND nom_accion = p_action          -- Misma acción
      AND fec_intento > (NOW() - (p_window || ' minutes')::INTERVAL);
      -- ^ Solo cuenta intentos de los últimos p_window minutos
      -- Ejemplo: si p_window=15, solo cuenta los de los últimos 15 min

    -- Si la cantidad de intentos es MENOR que el límite → permitido
    RETURN v_count < p_limit;
END;
$$ LANGUAGE plpgsql STABLE;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 8: fn_sec_log_attempt                          ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Registrar un intento fallido de login     ║
-- ║               (o cualquier acción protegida).           ║
-- ║  Llamada PHP: SELECT fn_sec_log_attempt(                ║
-- ║                 '192.168.1.1', 'login_attempt')         ║
-- ║  Retorna    : VOID (no devuelve nada)                   ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. El login falla (contraseña incorrecta o user no     ║
-- ║     encontrado)                                         ║
-- ║  2. PHP llama esta función para registrar el intento    ║
-- ║  3. Se inserta una fila en tab_Rate_Limits              ║
-- ║  4. fn_sec_check_rate_limit la contará en futuras       ║
-- ║     verificaciones                                      ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE OR REPLACE FUNCTION fn_sec_log_attempt(
    p_ip     tab_Rate_Limits.identificador%TYPE,  -- IP del cliente que falló
    p_action tab_Rate_Limits.nom_accion%TYPE   -- Tipo de acción que falló
)
RETURNS VOID
AS $$
DECLARE
    v_new_id tab_Rate_Limits.id_rate_limit%TYPE;
BEGIN
    -- Auto-generar ID siguiendo el patrón del proyecto (sin SERIAL)
    SELECT COALESCE(MAX(id_rate_limit), 0) + 1 INTO v_new_id FROM tab_Rate_Limits;

    INSERT INTO tab_Rate_Limits (
        id_rate_limit,  -- ID auto-calculado
        identificador,  -- La IP del cliente
        nom_accion,     -- Qué acción intentó ('login_attempt')
        fec_intento,    -- Cuándo fue el intento (ahora)
        usr_insert      -- Quién registró esto ('system')
    )
    VALUES (v_new_id, p_ip, p_action, NOW(), 'system');
END;
$$ LANGUAGE plpgsql;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 9: fn_sec_clear_attempts                       ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Limpiar todos los intentos fallidos       ║
-- ║               de una IP tras un login EXITOSO.          ║
-- ║  Llamada PHP: SELECT fn_sec_clear_attempts(             ║
-- ║                 '192.168.1.1', 'login_attempt')         ║
-- ║  Retorna    : VOID                                      ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. El login fue exitoso                                ║
-- ║  2. PHP llama esta función para "perdonar" los intentos ║
-- ║     fallidos anteriores                                 ║
-- ║  3. Se borran TODAS las filas de esa IP + acción        ║
-- ║  4. El usuario empieza con conteo limpio                ║
-- ║                                                         ║
-- ║  ¿Por qué borrar y no solo resetear un contador?        ║
-- ║  Porque tab_Rate_Limits almacena cada intento como      ║
-- ║  una fila individual con timestamp, permitiendo         ║
-- ║  análisis temporales más detallados si se necesitan.    ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE OR REPLACE FUNCTION fn_sec_clear_attempts(
    p_ip     tab_Rate_Limits.identificador%TYPE,  -- IP del cliente que tuvo éxito
    p_action tab_Rate_Limits.nom_accion%TYPE   -- Acción que tuvo éxito
)
RETURNS VOID
AS $$
BEGIN
    -- Borra TODOS los registros de intentos de esta IP para esta acción
    DELETE FROM tab_Rate_Limits
    WHERE identificador = p_ip
      AND nom_accion = p_action;
END;
$$ LANGUAGE plpgsql;
