<?php
ini_set('display_errors', 1);
error_reporting(E_ALL);

$envFile = __DIR__ . '/.env';
$env = parse_ini_file($envFile);

try {
    $dsn = "pgsql:host={$env['DB_HOST']};port={$env['DB_PORT']};dbname={$env['DB_NAME']}";
    $pdo = new PDO($dsn, $env['DB_USER'], $env['DB_PASS'], [
        PDO::ATTR_ERRMODE => PDO::ERRMODE_EXCEPTION
    ]);
} catch (PDOException $e) {
    die("Error de conexión PDO: " . $e->getMessage());
}

try {
    $pdo->beginTransaction();

    // 1. Añadir columnas OAuth
    $pdo->exec("ALTER TABLE tab_Usuarios ADD COLUMN IF NOT EXISTS oauth_provider VARCHAR(50);");
    $pdo->exec("ALTER TABLE tab_Usuarios ADD COLUMN IF NOT EXISTS oauth_uid VARCHAR(255);");

    // 2. Hacer opcionales los campos `contra` y `num_telefono_usuario` para cuentas OAuth
    $pdo->exec("ALTER TABLE tab_Usuarios ALTER COLUMN contra DROP NOT NULL;");
    $pdo->exec("ALTER TABLE tab_Usuarios ALTER COLUMN num_telefono_usuario DROP NOT NULL;");

    // 3. Crear función de inicio de sesión / registro OAuth
    $sqlFunction = "
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
        -- 1. Buscar si el usuario ya inició sesión con este proveedor antes
        SELECT id_usuario INTO v_user_id FROM tab_Usuarios 
        WHERE oauth_provider = p_provider AND oauth_uid = p_oauth_uid;
        
        IF v_user_id IS NULL THEN
            -- 2. No existe la cuenta OAuth. Buscar si ya existe una cuenta con ese email
            SELECT id_usuario INTO v_user_id FROM tab_Usuarios
            WHERE correo_usuario = p_email;
            
            IF v_user_id IS NOT NULL THEN
                -- Vincular la cuenta existente a OAuth
                UPDATE tab_Usuarios 
                SET oauth_provider = p_provider,
                    oauth_uid = p_oauth_uid,
                    fec_update = NOW(),
                    usr_update = 'system_oauth_link'
                WHERE id_usuario = v_user_id;
            ELSE
                -- 3. Crear nuevo usuario desde cero
                SELECT COALESCE(MAX(id_usuario), 0) + 1 INTO v_user_id FROM tab_Usuarios;
                
                INSERT INTO tab_Usuarios (
                    id_usuario,
                    nom_usuario,
                    correo_usuario,
                    num_telefono_usuario,
                    rol,
                    activo,
                    bloqueado,
                    fecha_registro,
                    oauth_provider,
                    oauth_uid
                ) VALUES (
                    v_user_id,
                    p_nombre,
                    p_email,
                    NULL, -- Teléfono no provisto por Google
                    'cliente',
                    TRUE,
                    FALSE,
                    NOW(),
                    p_provider,
                    p_oauth_uid
                );
            END IF;
        END IF;

        -- 4. Devolver perfil básico de sesión
        SELECT row_to_json(t) INTO v_result FROM (
            SELECT id_usuario, nom_usuario, rol, activo, bloqueado
            FROM tab_Usuarios
            WHERE id_usuario = v_user_id
        ) t;
        
        RETURN v_result;
    END;
    $$ LANGUAGE plpgsql;
    ";
    
    $pdo->exec($sqlFunction);
    $pdo->commit();
    echo "Migración completada exitosamente.\n";
} catch (Exception $e) {
    if ($pdo->inTransaction()) {
        $pdo->rollBack();
    }
    echo "Error en migración: " . $e->getMessage() . "\n";
}
