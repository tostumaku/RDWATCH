CREATE OR REPLACE FUNCTION fun_audit_rdwatch() 
RETURNS TRIGGER AS
$$
DECLARE
    v_estado_col TEXT;
BEGIN
    -- Para operaciones INSERT
    IF TG_OP = 'INSERT' THEN
        NEW.usr_insert := CURRENT_USER;
        NEW.fec_insert := CURRENT_TIMESTAMP;
        NEW.usr_update := CURRENT_USER;
        NEW.fec_update := CURRENT_TIMESTAMP;
        RETURN NEW;
    END IF;
    
    -- Para operaciones UPDATE
    IF TG_OP = 'UPDATE' THEN
        -- Preservar los valores originales de insert
        NEW.usr_insert := OLD.usr_insert;
        NEW.fec_insert := OLD.fec_insert;
        -- Actualizar solo los campos de update
        NEW.usr_update := CURRENT_USER;
        NEW.fec_update := CURRENT_TIMESTAMP;
        RETURN NEW;
    END IF;

    -- Para operaciones DELETE: interceptar y convertir en soft delete
    -- Cancela el DELETE físico, actualiza trazabilidad Y desactiva el registro.
    IF TG_OP = 'DELETE' THEN
        -- Determinar el nombre del campo "estado" según la tabla
        v_estado_col := CASE TG_TABLE_NAME
            WHEN 'tab_marcas'     THEN 'estado_marca'
            WHEN 'tab_categorias' THEN 'estado'
            WHEN 'tab_productos'  THEN 'estado'
            WHEN 'tab_servicios'  THEN 'estado'
            WHEN 'tab_subcategorias' THEN 'estado'
            ELSE NULL  -- Tablas sin campo estado: solo auditoría
        END;

        IF v_estado_col IS NOT NULL THEN
            -- Actualiza auditoría Y desactiva el registro en una sola operación
            EXECUTE format(
                'UPDATE %I.%I SET usr_delete = $1, fec_delete = $2, %I = FALSE WHERE ctid = $3',
                TG_TABLE_SCHEMA, TG_TABLE_NAME, v_estado_col
            ) USING CURRENT_USER, CURRENT_TIMESTAMP, OLD.ctid;
        ELSE
            -- Solo auditoría de trazabilidad, sin campo estado
            EXECUTE format(
                'UPDATE %I.%I SET usr_delete = $1, fec_delete = $2 WHERE ctid = $3',
                TG_TABLE_SCHEMA, TG_TABLE_NAME
            ) USING CURRENT_USER, CURRENT_TIMESTAMP, OLD.ctid;
        END IF;

        RETURN NULL; -- Cancela el DELETE físico
    END IF;

    RETURN NEW;
END;
$$
LANGUAGE PLPGSQL;

CREATE TRIGGER tri_audit_marcas 
    BEFORE INSERT OR UPDATE OR DELETE ON tab_Marcas
    FOR EACH ROW 
    EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_usuarios 
    BEFORE INSERT OR UPDATE OR DELETE ON tab_Usuarios
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_categorias 
    BEFORE INSERT OR UPDATE OR DELETE ON tab_Categorias
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_subcategorias 
    BEFORE INSERT OR UPDATE OR DELETE ON tab_Subcategorias
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_departamentos 
    BEFORE INSERT OR UPDATE ON tab_Departamentos
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_productos 
    BEFORE INSERT OR UPDATE OR DELETE ON tab_Productos
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_servicios 
    BEFORE INSERT OR UPDATE OR DELETE ON tab_Servicios
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_carrito 
    BEFORE INSERT OR UPDATE ON tab_Carrito
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

-- tab_Carrito_Detalle: hard delete intencional (datos transaccionales, sin usr_delete)
CREATE TRIGGER tri_audit_carrito_detalle 
    BEFORE INSERT OR UPDATE ON tab_Carrito_Detalle
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_orden 
    BEFORE INSERT OR UPDATE OR DELETE ON tab_Orden
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_detalle_orden 
    BEFORE INSERT OR UPDATE OR DELETE ON tab_Detalle_Orden
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_facturas 
    BEFORE INSERT OR UPDATE OR DELETE ON tab_Facturas
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_detalle_factura 
    BEFORE INSERT OR UPDATE OR DELETE ON tab_Detalle_Factura
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_pagos 
    BEFORE INSERT OR UPDATE OR DELETE ON tab_Pagos
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_envios 
    BEFORE INSERT OR UPDATE OR DELETE ON tab_Envios
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_opiniones 
    BEFORE INSERT OR UPDATE OR DELETE ON tab_Opiniones
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_metodos_pago 
    BEFORE INSERT OR UPDATE OR DELETE ON tab_Metodos_Pago
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_orden_servicios 
    BEFORE INSERT OR UPDATE OR DELETE ON tab_Orden_Servicios
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_reservas 
    BEFORE INSERT OR UPDATE OR DELETE ON tab_Reservas
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_contacto 
    BEFORE INSERT OR UPDATE OR DELETE ON tab_Contacto
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_empleados 
    BEFORE INSERT OR UPDATE OR DELETE ON tab_Empleados
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_eventos 
    BEFORE INSERT OR UPDATE OR DELETE ON tab_Eventos
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_ciudades 
    BEFORE INSERT OR UPDATE ON tab_Ciudades
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

CREATE TRIGGER tri_audit_direcciones_envio 
    BEFORE INSERT OR UPDATE OR DELETE ON tab_Direcciones_Envio
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();

-- tab_Rate_Limits: solo INSERT/UPDATE (sin usr_delete, datos de seguridad temporales)
CREATE TRIGGER tri_audit_rate_limits 
    BEFORE INSERT ON tab_Rate_Limits
    FOR EACH ROW EXECUTE FUNCTION fun_audit_rdwatch();
