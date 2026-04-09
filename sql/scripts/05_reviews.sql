-- =====================================================
-- Datos de prueba para tab_Opiniones
-- =====================================================

-- Insertamos algunas reseñas de prueba vinculadas a usuarios existentes
-- Nota: Asumimos que existen usuarios con ID 101, 102, 103 (ajustar si es necesario)
-- O mejor, usamos una subconsulta para obtener IDs reales si están disponibles

INSERT INTO tab_Opiniones (id_opinion, id_usuario, calificacion, comentario, usr_insert)
SELECT 1, id_usuario, 5, '¡Excelente servicio! Mi reloj quedó como nuevo. Muy recomendados.', 'sistema'
FROM tab_Usuarios
LIMIT 1;

INSERT INTO tab_Opiniones (id_opinion, id_usuario, calificacion, comentario, usr_insert)
SELECT 2, id_usuario, 4, 'Muy buena atención, aunque tardaron un poco más de lo esperado en la reparación.', 'sistema'
FROM tab_Usuarios
OFFSET 1 LIMIT 1;

INSERT INTO tab_Opiniones (id_opinion, id_usuario, calificacion, comentario, usr_insert)
SELECT 3, id_usuario, 5, 'La mejor relojería de Bucaramanga. Tres generaciones de confianza.', 'sistema'
FROM tab_Usuarios
OFFSET 2 LIMIT 1;
