-- POBLACIÓN DE USUARIOS PERSONALIZADOS - RD WATCH V2
-- Patrón de correo: cliente[N]@email.com
-- Patrón de contraseña: Cliente123![N]

-- 1. Administrador y Clientes Base
-- Eliminamos el borrado masivo para preservar los seeders de 05_seeders.sql

INSERT INTO tab_Usuarios (id_usuario, nom_usuario, correo_usuario, num_telefono_usuario, contra, rol, direccion_principal, activo, fec_insert, usr_insert)
VALUES (1, 'Administrador RD Watch', 'admin@rdwatch.com', 3115460069, '$2b$12$7piCEjqRgZvt0S9b.hrRC.u9IEZvceySXtJzlWtO6SweGlqQQuJu.', 'admin', 'Calle 34 #18-40 local 107', TRUE, NOW(), 'system');

-- 2. Cliente por Defecto
INSERT INTO tab_Usuarios (id_usuario, nom_usuario, correo_usuario, num_telefono_usuario, contra, rol, direccion_principal, activo, fec_insert, usr_insert)
VALUES (2, 'Cliente de Prueba', 'cliente@rdwatch.com', 3001234567, '$2y$10$I.llqxg0unGZ6GZ2ey1pYOLDIKDCLDy9XO9j03BDe0m2.nCPqKeYu', 'cliente', 'Carrera 10 #20-30, Bogotá', TRUE, NOW(), 'system');
