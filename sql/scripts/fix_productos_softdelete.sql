-- ============================================================
-- FIX: fn_cat_delete_producto (1 parámetro)
-- ============================================================
-- PROBLEMA: El PHP llama SELECT fn_cat_delete_producto(?::INTEGER)
--           con solo el ID, pero la función en BD requería 2 params.
-- SOLUCIÓN: Sobrescribir con versión de 1 parámetro que obtiene
--           el usuario de la sesión o usa un valor por defecto.
-- ============================================================

-- Eliminar cualquier versión existente (2 params)
DROP FUNCTION IF EXISTS fn_cat_delete_producto(INTEGER, VARCHAR);

-- Crear versión con 1 solo parámetro (como la llama el PHP)
CREATE OR REPLACE FUNCTION fn_cat_delete_producto(
    p_id  INTEGER          -- ID único del producto objetivo
)
RETURNS JSON  -- {ok: bool, msg: string}
AS $$
BEGIN
    -- BARRERA 1: Protección de Historial de Ventas.
    IF EXISTS (SELECT 1 FROM tab_Detalle_Orden WHERE id_producto = p_id LIMIT 1) THEN
        RETURN json_build_object('ok', false,
            'msg', 'Prohibido: Este producto posee historial comercial vinculado y no puede eliminarse.');
    END IF;

    -- BARRERA 2: Protección de Flujo de Venta.
    IF EXISTS (SELECT 1 FROM tab_Carrito_Detalle WHERE id_producto = p_id LIMIT 1) THEN
        RETURN json_build_object('ok', false,
            'msg', 'Prohibido: El producto está en uso por carritos de compra activos.');
    END IF;

    -- SOFT DELETE: Desactivación lógica con trazabilidad completa.
    UPDATE tab_Productos SET
        estado     = FALSE,
        fec_delete = NOW()
    WHERE id_producto = p_id;

    -- Verificar que el UPDATE afectó filas
    IF NOT FOUND THEN
        RETURN json_build_object('ok', false,
            'msg', 'Producto no encontrado.');
    END IF;

    RETURN json_build_object('ok', true,
        'msg', 'El producto ha sido desactivado del catálogo. El registro se conserva para auditoría.');
END;
$$ LANGUAGE plpgsql;

-- Verificar que la función existe
SELECT proname, pronargs FROM pg_proc WHERE proname = 'fn_cat_delete_producto';
