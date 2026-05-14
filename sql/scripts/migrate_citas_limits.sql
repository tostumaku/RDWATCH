-- ═══════════════════════════════════════════════════════════════
-- MIGRACIÓN: Control de Límites para Citas/Servicios
-- Fecha: 28 Abril 2026
-- Descripción: Agrega rate limits, validación de fecha preferida
--   (no domingos, anticipación mínima) y restricción de cancelación.
--   El usuario puede solicitar citas 24/7. Las restricciones
--   aplican a la FECHA SELECCIONADA, no al momento de la solicitud.
-- Ejecutar en: db_rdwatch
-- Comando: psql -U <usuario> -d db_rdwatch -f migrate_citas_limits.sql
-- ═══════════════════════════════════════════════════════════════

-- ──────────────────────────────────────────────
-- 1. REEMPLAZAR fn_citas_create
-- ──────────────────────────────────────────────
DROP FUNCTION IF EXISTS fn_citas_create(bigint, bigint, date, text, text);
DROP FUNCTION IF EXISTS fn_citas_create(integer, integer, date, text, text);
CREATE OR REPLACE FUNCTION fn_citas_create(
    p_user_id     tab_Usuarios.id_usuario%TYPE,
    p_servicio_id tab_Servicios.id_servicio%TYPE,
    p_fecha       tab_Reservas.fecha_preferida%TYPE,
    p_prioridad   tab_Reservas.prioridad%TYPE,
    p_notas       tab_Reservas.notas_cliente%TYPE
)
RETURNS JSON
AS $$
DECLARE
    v_new_id   tab_Reservas.id_reserva%TYPE;
    v_now      TIMESTAMP;
    v_count    SMALLINT;
BEGIN
    SET LOCAL timezone = 'America/Bogota';
    v_now := NOW();

    -- Validación 1: Anticipación mínima (2 días)
    IF p_fecha < (CURRENT_DATE + 2) THEN
        RETURN json_build_object('ok', false,
            'msg', 'Fecha inválida: La fecha preferida debe ser al menos 2 días después de hoy (' || TO_CHAR(CURRENT_DATE + 2, 'DD/MM/YYYY') || ' en adelante).');
    END IF;

    -- Validación 2: Fecha preferida NO puede ser domingo
    IF EXTRACT(DOW FROM p_fecha) = 0 THEN
        RETURN json_build_object('ok', false,
            'msg', 'Fecha no disponible: No se atienden servicios los domingos. Horario disponible: Lunes a Viernes 10AM–6PM, Sábados 10AM–3PM.');
    END IF;

    -- Validación 3: Anti-duplicado
    IF EXISTS (
        SELECT 1 FROM tab_Reservas
        WHERE id_usuario = p_user_id
          AND id_servicio = p_servicio_id
          AND fecha_preferida = p_fecha
          AND estado_reserva IN ('pendiente', 'confirmada')
    ) THEN
        RETURN json_build_object('ok', false,
            'msg', 'Acción denegada: Ya cuenta con una solicitud activa para este servicio en la fecha indicada.');
    END IF;

    -- Validación 4: Límite diario por cliente (máx 1/día por fecha de creación)
    SELECT COUNT(1) INTO v_count
    FROM tab_Reservas
    WHERE id_usuario = p_user_id
      AND fecha_reserva::DATE = CURRENT_DATE
      AND estado_reserva IN ('pendiente', 'confirmada');

    IF v_count >= 1 THEN
        RETURN json_build_object('ok', false,
            'msg', 'Límite alcanzado: Solo puede realizar 1 solicitud de servicio por día. Intente nuevamente mañana.');
    END IF;

    -- Validación 5: Límite semanal por cliente (máx 2/semana por fecha de creación)
    SELECT COUNT(1) INTO v_count
    FROM tab_Reservas
    WHERE id_usuario = p_user_id
      AND fecha_reserva >= DATE_TRUNC('week', CURRENT_DATE)
      AND estado_reserva IN ('pendiente', 'confirmada');

    IF v_count >= 2 THEN
        RETURN json_build_object('ok', false,
            'msg', 'Límite semanal alcanzado: Solo puede realizar 2 solicitudes por semana. Intente la próxima semana.');
    END IF;

    -- Validación 6: Límite global (máx 10 citas por fecha_preferida)
    SELECT COUNT(1) INTO v_count
    FROM tab_Reservas
    WHERE fecha_preferida = p_fecha
      AND estado_reserva IN ('pendiente', 'confirmada');

    IF v_count >= 10 THEN
        RETURN json_build_object('ok', false,
            'msg', 'Agenda completa: La fecha seleccionada ya tiene el máximo de citas permitidas (10). Por favor, seleccione otro día.');
    END IF;

    -- Inserción
    SELECT COALESCE(MAX(r.id_reserva), 0) + 1 INTO v_new_id FROM tab_Reservas r;

    INSERT INTO tab_Reservas (
        id_reserva, id_usuario, id_servicio, fecha_preferida,
        notas_cliente, prioridad, estado_reserva, fecha_reserva,
        usr_insert, fec_insert
    ) VALUES (
        v_new_id, p_user_id, p_servicio_id, p_fecha,
        p_notas, p_prioridad, 'pendiente', v_now,
        'usr_web_client', v_now
    );

    RETURN json_build_object('ok', true, 'msg', 'Su solicitud ha sido agendada exitosamente. Un técnico la revisará a la brevedad.');
END;
$$ LANGUAGE plpgsql;

-- ──────────────────────────────────────────────
-- 2. REEMPLAZAR fn_citas_update_status
-- ──────────────────────────────────────────────
DROP FUNCTION IF EXISTS fn_citas_update_status(bigint, text, text);
DROP FUNCTION IF EXISTS fn_citas_update_status(integer, text, text);
CREATE OR REPLACE FUNCTION fn_citas_update_status(
    p_reserva_id  tab_Reservas.id_reserva%TYPE,
    p_new_status  tab_Reservas.estado_reserva%TYPE,
    p_admin_id    tab_Reservas.usr_update%TYPE
)
RETURNS JSON
AS $$
DECLARE
    v_fecha_pref tab_Reservas.fecha_preferida%TYPE;
BEGIN
    SET LOCAL timezone = 'America/Bogota';

    -- Cancelación anticipada: solo clientes (no admin)
    IF p_new_status = 'cancelada' AND LEFT(p_admin_id, 6) <> 'admin_' THEN
        SELECT r.fecha_preferida INTO v_fecha_pref
        FROM tab_Reservas r
        WHERE r.id_reserva = p_reserva_id;

        IF v_fecha_pref IS NULL THEN
            RETURN json_build_object('ok', false,
                'msg', 'Error: No se encontró la cita especificada.');
        END IF;

        IF v_fecha_pref <= (CURRENT_DATE + 1) THEN
            RETURN json_build_object('ok', false,
                'msg', 'No es posible cancelar: Las citas solo pueden cancelarse con al menos 1 día de anticipación antes de la fecha programada.');
        END IF;
    END IF;

    UPDATE tab_Reservas
    SET estado_reserva = p_new_status,
        usr_update = p_admin_id,
        fec_update = NOW()
    WHERE id_reserva = p_reserva_id;

    RETURN json_build_object('ok', true, 'msg', 'El estado de la cita técnica ha sido actualizado.');
END;
$$ LANGUAGE plpgsql;

-- ──────────────────────────────────────────────
-- VERIFICACIÓN
-- ──────────────────────────────────────────────
DO $$
BEGIN
    RAISE NOTICE '✅ Migración completada: fn_citas_create y fn_citas_update_status actualizadas con rate limits y validaciones de fecha.';
END $$;
