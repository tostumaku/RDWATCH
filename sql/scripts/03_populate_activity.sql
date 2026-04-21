-- POBLACIÓN DE ACTIVIDAD MASIVA - RD WATCH V2
-- Propósito: Generar 70+ pedidos y 35+ citas (100+ interacciones) para simulación real.

-- 1. LIMPIAR DATOS PREVIOS DE ACTIVIDAD
DELETE FROM tab_Pagos;
DELETE FROM tab_Envios;
DELETE FROM tab_Detalle_Factura;
DELETE FROM tab_Facturas;
DELETE FROM tab_Detalle_Orden;
DELETE FROM tab_Orden;
DELETE FROM tab_Reservas;

-- 2. GENERACIÓN DE ÓRDENES (Lógica manual para asegurar IDs y consistencia)
-- Generaremos bloques de órdenes para distintos usuarios.
-- Usuario 2 (Juan Perez) - Cliente frecuente
INSERT INTO tab_Orden (id_orden, id_usuario, fecha_orden, estado_orden, total_orden, concepto, fec_insert, usr_insert) VALUES
(2001, 2, NOW() - INTERVAL '10 days', 'enviado', 68500000, 'Envío a domicilio - Rolex Submariner', NOW(), 'system'),
(2002, 2, NOW() - INTERVAL '5 days', 'confirmado', 320000, 'Pedido Casio Retro', NOW(), 'system'),
(2003, 2, NOW() - INTERVAL '1 day', 'pendiente', 450000, 'Kit de limpieza y accesorios', NOW(), 'system');

-- Usuario 3 (Maria)
INSERT INTO tab_Orden (id_orden, id_usuario, fecha_orden, estado_orden, total_orden, concepto, fec_insert, usr_insert) VALUES
(2004, 3, NOW() - INTERVAL '15 days', 'enviado', 28900000, 'Compra Omega Seamaster', NOW(), 'system'),
(2005, 3, NOW() - INTERVAL '2 days', 'cancelado', 1850000, 'Error en pedido G-Shock', NOW(), 'system');

-- Bucle de 65 pedidos adicionales (IDs 2006 a 2070) distribuidos en los 30 usuarios
-- Usando una técnica de INSERT masivo con IDs precalculados para evitar scripts complejos
DO $$
DECLARE 
    i INT;
    u_id INT;
    est VARCHAR;
    total DECIMAL;
BEGIN
    FOR i IN 2006..2070 LOOP
        u_id := (i % 29) + 2; -- Rota entre usuarios 2 y 30
        est := CASE (i % 4) 
                WHEN 0 THEN 'enviado' 
                WHEN 1 THEN 'confirmado' 
                WHEN 2 THEN 'pendiente' 
                ELSE 'cancelado' 
               END;
        total := (i * 1500) + (u_id * 500); -- Valores variados
        
        INSERT INTO tab_Orden (id_orden, id_usuario, fecha_orden, estado_orden, total_orden, concepto, fec_insert, usr_insert)
        VALUES (i, u_id, NOW() - (i % 30 || ' days')::INTERVAL, est, total, 'Pedido automático de prueba #' || i, NOW(), 'system');
        
        -- Detalle de Orden básico para que no esté vacío
        INSERT INTO tab_Detalle_Orden (id_detalle_orden, id_orden, id_producto, cantidad, precio_unitario, fec_insert, usr_insert)
        VALUES (i*10, i, (i % 50) + 1, 1, total, NOW(), 'system');
        
        -- Factura básica
        INSERT INTO tab_Facturas (id_factura, id_orden, id_usuario, fecha_emision, total_factura, estado_factura, fec_insert, usr_insert)
        VALUES (i+5000, i, u_id, NOW() - (i % 30 || ' days')::INTERVAL, total, 'Emitida', NOW(), 'system');
        
        -- Pago (solo para enviados y confirmados)
        IF est IN ('enviado', 'confirmado') THEN
            INSERT INTO tab_Pagos (id_pago, id_orden, monto, id_metodo_pago, estado_pago, fecha_pago, fec_insert, usr_insert)
            VALUES (i+10000, i, total, 1, 'completado', NOW(), NOW(), 'system');
        END IF;

    END LOOP;
END $$;

-- 3. GENERACIÓN DE CITAS (35+ registros)
-- IDs 5001 a 5040
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
