-- POBLACIÓN DE ACTIVIDAD MASIVA - RD WATCH V2 (OPTIMIZADO PARA INNER JOINs)
-- Propósito: Generar 70+ pedidos y 35+ citas asegurando integridad en todas las tablas relacionadas.

-- 1. LIMPIAR DATOS PREVIOS
DELETE FROM tab_Pagos;
DELETE FROM tab_Envios;
DELETE FROM tab_Detalle_Factura;
DELETE FROM tab_Facturas;
DELETE FROM tab_Detalle_Orden;
DELETE FROM tab_Orden;
DELETE FROM tab_Reservas;
DELETE FROM tab_Direcciones_Envio; -- Limpiamos para evitar conflictos de IDs en semillas

-- 2. GENERACIÓN DE DIRECCIONES PARA CLIENTES (IDs 100..130)
DO $$
DECLARE
    u_id INT;
BEGIN
    FOR u_id IN 2..30 LOOP
        INSERT INTO tab_Direcciones_Envio (id_direccion, id_usuario, direccion_completa, id_ciudad, codigo_postal, es_predeterminada, fec_insert, usr_insert)
        VALUES (u_id + 100, u_id, 'Calle Simulación #' || u_id, (u_id % 5) + 1, '110' || u_id, TRUE, NOW(), 'system');
    END LOOP;
END $$;

-- 3. GENERACIÓN DE ÓRDENES Y DEPENDENCIAS
DO $$
DECLARE 
    i INT;
    u_id INT;
    est VARCHAR;
    total DECIMAL;
    v_pag_est VARCHAR;
    v_env_est VARCHAR;
BEGIN
    -- Generar 70 pedidos (IDs 2001 a 2070)
    FOR i IN 2001..2070 LOOP
        u_id := (i % 29) + 2; -- Rota entre usuarios 2 y 30
        
        -- Lógica de estados para variedad
        est := CASE (i % 4) 
                WHEN 0 THEN 'enviado' 
                WHEN 1 THEN 'confirmado' 
                WHEN 2 THEN 'pendiente' 
                ELSE 'cancelado' 
               END;
               
        v_pag_est := CASE est WHEN 'cancelado' THEN 'fallido' WHEN 'pendiente' THEN 'pendiente' ELSE 'completado' END;
        v_env_est := CASE est WHEN 'enviado' THEN 'en tránsito' WHEN 'cancelado' THEN 'cancelado' ELSE 'pendiente' END;
        
        total := (i * 1500) + (u_id * 500); 

        -- A. CABECERA DE ORDEN
        INSERT INTO tab_Orden (id_orden, id_usuario, fecha_orden, estado_orden, total_orden, concepto, fec_insert, usr_insert)
        VALUES (i, u_id, NOW() - (i % 30 || ' days')::INTERVAL, est, total, 'Pedido de prueba #' || i, NOW(), 'system');
        
        -- B. DETALLE DE ORDEN
        INSERT INTO tab_Detalle_Orden (id_detalle_orden, id_orden, id_producto, cantidad, precio_unitario, fec_insert, usr_insert)
        VALUES (i, i, (i % 50) + 1, 1, total, NOW(), 'system');
        
        -- C. FACTURA
        INSERT INTO tab_Facturas (id_factura, id_orden, id_usuario, fecha_emision, total_factura, estado_factura, fec_insert, usr_insert)
        VALUES (i, i, u_id, NOW() - (i % 30 || ' days')::INTERVAL, total, 'Emitida', NOW(), 'system');
        
        -- D. PAGO (REQUERIDO POR INNER JOIN)
        INSERT INTO tab_Pagos (id_pago, id_orden, monto, id_metodo_pago, estado_pago, fecha_pago, fec_insert, usr_insert)
        VALUES (i, i, total, 1, v_pag_est, NOW(), NOW(), 'system');

        -- E. ENVÍO (REQUERIDO POR INNER JOIN)
        -- Usamos la dirección 100+u_id creada arriba
        INSERT INTO tab_Envios (id_envio, id_orden, id_direccion_envio, metodo_envio, estado_envio, fecha_envio, fecha_entrega_estimada, costo_envio, fec_insert, usr_insert)
        VALUES (i, i, u_id + 100, 'Envío Estándar', v_env_est, NOW(), NOW() + INTERVAL '3 days', 15000, NOW(), 'system');

    END LOOP;
END $$;

-- 4. GENERACIÓN DE CITAS (35+ registros)
DO $$
DECLARE 
    i INT;
    u_id INT;
    s_id INT;
    est VARCHAR;
    prio VARCHAR;
BEGIN
    FOR i IN 5001..5040 LOOP
        u_id := (i % 29) + 2;
        s_id := (i % 10) + 1;
        est := CASE (i % 4) 
                WHEN 0 THEN 'completada' 
                WHEN 1 THEN 'confirmada' 
                WHEN 2 THEN 'pendiente' 
                ELSE 'cancelada' 
               END;
        prio := CASE (i % 3) WHEN 0 THEN 'alta' ELSE 'normal' END;

        INSERT INTO tab_Reservas (id_reserva, id_usuario, id_servicio, fecha_reserva, fecha_preferida, prioridad, estado_reserva, notas_cliente, fec_insert, usr_insert)
        VALUES (i, u_id, s_id, NOW() - (i % 20 || ' days')::INTERVAL, (CURRENT_DATE + (i % 15)), prio, est, 'Simulación de falla en reloj #' || i, NOW(), 'system');
    END LOOP;
END $$;
