-- =======================================================================
-- SCRIPT CORRECTIVO: REASIGNACIÓN DE PARÁMETROS PARA FN_CAT_UPDATE_SUBCATEGORIA
-- =======================================================================
-- NOTA: Este script elimina las versiones previas de la función (en caso de sobrecargas residuales)
-- y fuerza la creación de la función con los tipos de parámetros correctos.

-- 1. Eliminar cualquier versión de la función
DROP FUNCTION IF EXISTS fn_cat_update_subcategoria(INTEGER, INTEGER, VARCHAR);
DROP FUNCTION IF EXISTS fn_cat_update_subcategoria(INTEGER, INTEGER, TEXT);
DROP FUNCTION IF EXISTS fn_cat_update_subcategoria(INTEGER, INTEGER, TEXT, BOOLEAN);
DROP FUNCTION IF EXISTS fn_cat_update_subcategoria(SMALLINT, SMALLINT, TEXT, BOOLEAN);

-- 2. Recrear con tipos exactos a los que usa la Base de Datos nativa
CREATE OR REPLACE FUNCTION fn_cat_update_subcategoria(
    p_id_cat  SMALLINT,  -- ID del padre (tipo de tab_Subcategorias.id_categoria)
    p_id_sub  SMALLINT,  -- ID del hijo  (tipo de tab_Subcategorias.id_subcategoria)
    p_nombre  TEXT,      -- Nuevo nombre
    p_estado  BOOLEAN DEFAULT TRUE  -- Nuevo estado (permite reactivar)
) RETURNS JSON AS $$
BEGIN
    -- DML focalizado por clave compuesta.
    UPDATE tab_Subcategorias SET 
        nom_subcategoria = p_nombre,
        estado = p_estado,
        fec_update = NOW(), 
        usr_update = 'admin_editor'
    WHERE id_categoria = p_id_cat AND id_subcategoria = p_id_sub;

    RETURN json_build_object('ok', true, 'msg', 'Información de subcategoría actualizada.');
END;
$$ LANGUAGE plpgsql;
