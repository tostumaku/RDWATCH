SELECT fun_registrar_usuario(
    'Admin',
    'admin@rdwatch.com',
    3115460069,
    'Admin123.',
    'Calle 34 #18-40 local 107'
);

-- 2. Cambiar rol a admin
UPDATE tab_Usuarios 
SET rol = 'admin'
WHERE correo_usuario = 'admin@rdwatch.com';

-- 3. Verificar
SELECT id_usuario, nom_usuario, correo_usuario, rol 
FROM tab_Usuarios 
WHERE correo_usuario = 'admin@rdwatch.com';

SELECT * FROM tab_Usuarios;