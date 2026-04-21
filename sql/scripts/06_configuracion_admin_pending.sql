-- =====================================================
-- Configuración del Administrador Inicial
-- =====================================================

-- 1. Insertar el usuario administrador
-- Nota: La contraseña es 'Admin123.' (Hash Bcrypt)
INSERT INTO tab_Usuarios (
    id_usuario, 
    nom_usuario, 
    correo_usuario, 
    num_telefono_usuario, 
    direccion_principal, 
    contra, 
    rol, 
    activo,
    usr_insert,
    fec_insert
) VALUES (
    1, 
    'Admin', 
    'admin@rdwatch.com', 
    3115460069, 
    'Calle 34 #18-40 local 107', 
    '$2b$12$7piCEjqRgZvt0S9b.hrRC.u9IEZvceySXtJzlWtO6SweGlqQQuJu.', -- Hash para 'Admin123.'
    'admin', 
    TRUE,
    'system',
    CURRENT_TIMESTAMP
) ON CONFLICT (id_usuario) DO UPDATE 
SET rol = 'admin', 
    activo = TRUE,
    nom_usuario = EXCLUDED.nom_usuario,
    contra = EXCLUDED.contra,
    num_telefono_usuario = EXCLUDED.num_telefono_usuario,
    direccion_principal = EXCLUDED.direccion_principal;

-- 2. Verificar datos cargados
SELECT id_usuario, nom_usuario, correo_usuario, rol 
FROM tab_Usuarios 
WHERE correo_usuario = 'admin@rdwatch.com';

SELECT * FROM tab_Usuarios;