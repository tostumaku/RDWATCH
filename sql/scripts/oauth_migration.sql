-- ==============================================================
-- MIGRACIÓN PARA GOOGLE OAUTH
-- Ejecuta este script manualmente en pgAdmin, DBeaver o psql
-- ==============================================================

-- 1. Añadir columnas para almacenar información de redes sociales
ALTER TABLE tab_Usuarios ADD COLUMN IF NOT EXISTS oauth_provider VARCHAR(50);
ALTER TABLE tab_Usuarios ADD COLUMN IF NOT EXISTS oauth_uid VARCHAR(255);

-- 2. Quitar el requerimiento de contraseña y teléfono (Google no siempre lo da y no hay contraseña)
ALTER TABLE tab_Usuarios ALTER COLUMN contra DROP NOT NULL;
ALTER TABLE tab_Usuarios ALTER COLUMN num_telefono_usuario DROP NOT NULL;

-- 3. Crear una nueva función para iniciar sesión automáticamente o registrar cuentas de Google
CREATE OR REPLACE FUNCTION fn_auth_oauth_login(
    p_provider TEXT,
    p_oauth_uid TEXT,
    p_email TEXT,
    p_nombre TEXT
)
RETURNS JSON
AS $$
DECLARE
    v_user_id INTEGER;
    v_result JSON;
BEGIN
    -- Verificar si existe por provider + uid
    SELECT id_usuario INTO v_user_id FROM tab_Usuarios 
    WHERE oauth_provider = p_provider AND oauth_uid = p_oauth_uid;
    
    IF v_user_id IS NULL THEN
        -- Verificar si ya hay una cuenta vinculada a este email
        SELECT id_usuario INTO v_user_id FROM tab_Usuarios
        WHERE correo_usuario = p_email;
        
        IF v_user_id IS NOT NULL THEN
            -- Vincular la cuenta existente a Google
            UPDATE tab_Usuarios 
            SET oauth_provider = p_provider,
                oauth_uid = p_oauth_uid,
                fec_update = NOW(),
                usr_update = 'system_oauth_link'
            WHERE id_usuario = v_user_id;
        ELSE
            -- Crear nuevo usuario desde cero
            SELECT COALESCE(MAX(id_usuario), 0) + 1 INTO v_user_id FROM tab_Usuarios;
            
            INSERT INTO tab_Usuarios (
                id_usuario, nom_usuario, correo_usuario, num_telefono_usuario,
                rol, activo, bloqueado, fecha_registro, oauth_provider, oauth_uid
            ) VALUES (
                v_user_id, p_nombre, p_email, NULL,
                'cliente', TRUE, FALSE, NOW(), p_provider, p_oauth_uid
            );
        END IF;
    END IF;

    -- Devolver datos de sesión
    SELECT row_to_json(t) INTO v_result FROM (
        SELECT id_usuario, nom_usuario, rol, activo, bloqueado
        FROM tab_Usuarios
        WHERE id_usuario = v_user_id
    ) t;
    
    RETURN v_result;
END;
$$ LANGUAGE plpgsql;
