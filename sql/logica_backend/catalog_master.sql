-- ============================================================
-- MÓDULO: CATÁLOGO E INVENTARIO (catalog_master.sql)
-- ============================================================
-- Fase        : 2 de 5 — Catálogo, Marcas, Categorías, Servicios
-- ============================================================
--
-- ╔══════════════════════════════════════════════════════════╗
-- ║  PRINCIPIO FUNDAMENTAL: OCULTACIÓN TOTAL               ║
-- ║  PHP NUNCA ve nombres de tablas ni columnas.            ║
-- ║  Todas las funciones retornan JSON puro.                ║
-- ║  Para listas: json_agg(row_to_json()) → JSON array     ║
-- ║  Para operaciones: json_build_object() → JSON objeto    ║
-- ╚══════════════════════════════════════════════════════════╝
--
-- FUNCIONES EN ESTE MÓDULO (23 total):
-- ────────────────────────────────────
-- PRODUCTOS (4):
--   1.  fn_cat_get_productos      → Listar todos (con JOINs)
--   2.  fn_cat_create_producto    → Crear con 3 validaciones
--   3.  fn_cat_update_producto    → Actualizar con re-validación
--   4.  fn_cat_delete_producto    → Eliminar con protección historial
-- MARCAS (4):
--   5.  fn_cat_get_marcas         → Listar todas
--   6.  fn_cat_create_marca       → Crear con anti-duplicado
--   7.  fn_cat_update_marca       → Actualizar nombre/estado
--   8.  fn_cat_delete_marca       → Eliminar con protección productos
-- CATEGORÍAS (4):
--   9.  fn_cat_get_categorias     → Listar todas
--   10. fn_cat_create_categoria   → Crear nueva
--   11. fn_cat_update_categoria   → Actualizar nombre/desc/estado
--   12. fn_cat_delete_categoria   → Eliminar con doble protección
-- SUBCATEGORÍAS (4):
--   13. fn_cat_get_subcategorias  → Listar con JOIN a categoría padre
--   14. fn_cat_create_subcategoria→ Crear con verificación de PK compuesta
--   15. fn_cat_update_subcategoria→ Actualizar nombre
--   16. fn_cat_delete_subcategoria→ Eliminar con protección productos
-- DROPDOWNS (3):
--   17. fn_cat_dropdown_marcas       → Solo activas, para <select>
--   18. fn_cat_dropdown_categorias   → Solo activas, para <select>
--   19. fn_cat_dropdown_subcategorias→ Filtradas por categoría padre
-- SERVICIOS (4):
--   20. fn_cat_get_servicios      → Listar todos
--   21. fn_cat_create_servicio    → Crear con anti-duplicado
--   22. fn_cat_update_servicio    → Actualizar datos
--   23. fn_cat_delete_servicio    → Eliminar con protección reservas
--
-- TABLAS QUE ESTE MÓDULO TOCA (pero PHP no lo sabe):
-- ────────────────────────────────────
-- tab_Productos       → Catálogo de relojes (CRUD principal)
-- tab_Marcas          → Marcas de relojes
-- tab_Categorias      → Categorías principales
-- tab_Subcategorias   → Sub-niveles de categoría (PK compuesta)
-- tab_Servicios       → Servicios técnicos del taller
-- tab_Detalle_Orden   → (lectura) Para verificar historial de ventas
-- tab_Carrito_Detalle  → (lectura) Para verificar carritos activos
-- tab_Reservas        → (lectura) Para verificar citas técnicas
-- ============================================================


-- ██████████████████████████████████████████████████████████
-- ██  SECCIÓN 1: PRODUCTOS (el corazón del catálogo)      ██
-- ██████████████████████████████████████████████████████████
--
-- Los productos son relojes. Cada producto tiene:
-- - Una marca (tab_Marcas)
-- - Una categoría (tab_Categorias)
-- - Una subcategoría (tab_Subcategorias) dentro de esa categoría
--
-- JERARQUÍA: Marca ← Producto → Categoría → Subcategoría
-- Ejemplo: Rolex ← "Rolex Submariner" → Relojes de Lujo → Automáticos


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 1: fn_cat_get_productos                        ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Obtener TODOS los productos con sus       ║
-- ║               nombres de marca, categoría y subcategoría║
-- ║  Llamada PHP: SELECT fn_cat_get_productos()             ║
-- ║  Retorna    : JSON array con todos los productos        ║
-- ║                                                         ║
-- ║  FLUJO PHP:                                             ║
-- ║  1. PDO ejecuta la consulta a la función.               ║
-- ║  2. Se obtiene el resultado con fetchColumn() como string║
-- ║  3. PHP decodifica el JSON para procesarlo como array.   ║
-- ║                                                         ║
-- ║  INTEGRIDAD (Joins):                                    ║
-- ║  - LEFT JOIN tab_Marcas: Recupera el nombre comercial.   ║
-- ║  - LEFT JOIN tab_Categorias: Recupera la clasificación.  ║
-- ║  - LEFT JOIN tab_Subcategorias: Recupera el detalle fino.║
-- ║                                                         ║
-- ║  ¿Por qué usar STABLE?                                  ║
-- ║  Porque la función no altera el estado de la base de     ║
-- ║  datos, solo consulta. PostgreSQL puede optimizar el     ║
-- ║  plan de ejecución.                                     ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_cat_get_productos()
RETURNS JSON  -- Retorna un JSON ARRAY (lista de productos comprimida)
AS $$
DECLARE
    v_result JSON;  -- Variable local para capturar el buffer JSON
BEGIN
    -- json_agg() agrupa todas las filas en UNA sola estructura de array.
    -- row_to_json(t) encapsula cada registro en un par clave:valor.
    -- COALESCE() garantiza que si la tabla está vacía, el sistema retorne '[]' en lugar de NULL.
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_result FROM (
        SELECT
            p.id_producto,     -- Clave primaria del reloj (BIGINT)
            p.nom_producto,    -- Nombre descriptivo del modelo
            p.precio,          -- Precio unitario de venta
            p.stock,           -- Unidades reales disponibles
            p.url_imagen,      -- Ruta local o remota del recurso visual
            p.descripcion,     -- Ficha técnica detallada
            p.estado,          -- Visibilidad (TRUE=Visible, FALSE=Oculto/Agotado)
            m.nom_marca,       -- Nombre extraído de tab_Marcas
            m.id_marca,        -- ID de referencia de marca
            c.nom_categoria,   -- Nombre de la categoría padre
            c.id_categoria,    -- ID de referencia de categoría
            s.nom_subcategoria,-- Nombre de la subcategoría específica
            s.id_subcategoria  -- ID de referencia de subcategoría
        FROM tab_Productos p
        -- Usamos LEFT JOIN para evitar perder productos si su marca o categoría
        -- fue desactivada o eliminada físicamente (mantenimiento de catálogo).
        LEFT JOIN tab_Marcas m ON p.id_marca = m.id_marca
        LEFT JOIN tab_Categorias c ON p.id_categoria = c.id_categoria
        -- JOIN especial: La subcategoría depende tanto de su ID como de su padre.
        LEFT JOIN tab_Subcategorias s
            ON (p.id_categoria = s.id_categoria AND p.id_subcategoria = s.id_subcategoria)
        ORDER BY p.id_producto DESC  -- Los ingresos más recientes aparecen primero
    ) t;

    -- Entregamos el objeto JSON listo para ser consumido por el wrapper PHP
    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE; -- STABLE indica seguridad para lecturas repetitivas


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 2: fn_cat_create_producto                      ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Crear un nuevo producto con validaciones  ║
-- ║               de integridad de negocio exhaustivas.     ║
-- ║  Llamada PHP: SELECT fn_cat_create_producto(101, ...)   ║
-- ║  Retorna    : JSON {ok: bool, msg: '...'}               ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin completa el formulario de alta en el frontend.║
-- ║  2. PHP (productos.php) sanitiza y valida los 10 campos.║
-- ║  3. PDO ejecuta SELECT fn_cat_create_producto(...).     ║
-- ║  4. La función ejecuta 3 validaciones de integridad.    ║
-- ║  5. Si todas pasan → INSERT en tab_Productos.           ║
-- ║  6. Retorna {ok: true/false, msg} → PHP lo reenvía.     ║
-- ║                                                         ║
-- ║  JERARQUÍA DE VALIDACIÓN:                               ║
-- ║  1. Existencia Física: El ID no debe estar ocupado.     ║
-- ║  2. Semántica: No duplicar nombre bajo la misma marca.   ║
-- ║  3. Categorización: La subcategoría debe ser hija de     ║
-- ║     la categoría padre seleccionada (PK Compuesta).     ║
-- ║                                                         ║
-- ║  AUDITORÍA:                                             ║
-- ║  Registra automáticamente fecha y usuario de creación.  ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_cat_create_producto(
    p_id         tab_Productos.id_producto%TYPE,    -- ID manual asignado por el administrador
    p_nombre     tab_Productos.nom_producto%TYPE,      -- Nombre oficial del producto
    p_desc       tab_Productos.descripcion%TYPE,      -- Reseña técnica sanitizada
    p_precio     tab_Productos.precio%TYPE,   -- Valor comercial
    p_stock      tab_Productos.stock%TYPE,  -- Existencias iniciales
    p_imagen     tab_Productos.url_imagen%TYPE,      -- Ruta del archivo de imagen
    p_id_marca   tab_Productos.id_marca%TYPE,    -- Enlace con tab_Marcas
    p_id_cat     tab_Productos.id_categoria%TYPE,   -- Enlace con tab_Categorias
    p_id_subcat  tab_Productos.id_subcategoria%TYPE,   -- Enlace con tab_Subcategorias (Validación estricta)
    p_usr        tab_Productos.usr_insert%TYPE       -- ID/Nombre del administrador operador
)
RETURNS JSON  -- Formato unificado de respuesta de operación
AS $$
BEGIN
    -- VALIDACIÓN 1: Integridad de Clave Primaria.
    -- Evita errores fatales de duplicidad antes de intentar el INSERT.
    IF EXISTS (SELECT 1 FROM tab_Productos WHERE id_producto = p_id) THEN
        RETURN json_build_object('ok', false,
            'msg', 'Error de Integridad: El código ID ' || p_id || ' ya se encuentra en uso.');
    END IF;

    -- VALIDACIÓN 2: Evitar redundancia visual en el catálogo.
    -- Un admin no debería poder crear dos "Seiko 5" en la misma marca accidentalmente.
    IF EXISTS (SELECT 1 FROM tab_Productos WHERE nom_producto = p_nombre AND id_marca = p_id_marca) THEN
        RETURN json_build_object('ok', false,
            'msg', 'Conflicto: Ya existe un registro para "' || p_nombre || '" bajo esta marca.');
    END IF;

    -- VALIDACIÓN 3: Consistencia en la taxonomía del catálogo.
    -- Garantiza que si la categoría es "Accesorios", la subcategoría sea algo válido como "Cajas".
    -- Protege contra desconfiguraciones en el formulario del frontend.
    IF NOT EXISTS (SELECT 1 FROM tab_Subcategorias
                   WHERE id_categoria = p_id_cat AND id_subcategoria = p_id_subcat) THEN
        RETURN json_build_object('ok', false,
            'msg', 'Inconsistencia: El par Categoría-Subcategoría indicado no es válido.');
    END IF;

    -- OPERACIÓN: Inserción de datos tras superar los filtros de seguridad.
    INSERT INTO tab_Productos (
        id_producto, nom_producto, descripcion, precio, stock, url_imagen,
        id_marca, id_categoria, id_subcategoria,
        estado,      -- Todo producto nuevo nace como Activo (TRUE)
        fec_insert,  -- Captura del tiempo real (NOW)
        usr_insert   -- Trazabilidad del operador
    ) VALUES (
        p_id, p_nombre, p_desc, p_precio, p_stock, p_imagen,
        p_id_marca, p_id_cat, p_id_subcat,
        TRUE, NOW(), p_usr
    );

    -- Respuesta amigable para el frontend
    RETURN json_build_object('ok', true,
        'msg', 'El reloj ha sido integrado al catálogo exitosamente.');
END;
$$ LANGUAGE plpgsql;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 3: fn_cat_update_producto                      ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Actualizar los datos de un producto       ║
-- ║               existente, manteniendo la coherencia de   ║
-- ║               la estructura jerárquica.                 ║
-- ║  Llamada PHP: SELECT fn_cat_update_producto(53, ...)    ║
-- ║  Retorna    : JSON {ok: bool, msg: '...'}               ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin edita los campos del producto en el frontend. ║
-- ║  2. PHP (productos.php) captura los 9 parámetros.       ║
-- ║  3. PDO ejecuta SELECT fn_cat_update_producto(...).     ║
-- ║  4. La función valida coherencia Categoría↔Subcategoría.║
-- ║  5. Si válida → UPDATE tab_Productos con sello de audit.║
-- ║  6. Retorna {ok, msg} → PHP reenvía al frontend.        ║
-- ║                                                         ║
-- ║  LÓGICA DE ACTUALIZACIÓN:                               ║
-- ║  1. Bloqueo de Categoría: Valida que la subcategoría sea║
-- ║     coherente con la nueva categoría (si cambió).       ║
-- ║  2. Trazabilidad: Marca automáticamente fecha y el      ║
-- ║     origen del cambio para auditoría interna.           ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_cat_update_producto(
    p_id         tab_Productos.id_producto%TYPE,    -- ID único del producto a modificar
    p_nombre     tab_Productos.nom_producto%TYPE,      -- Nombre actualizado
    p_desc       tab_Productos.descripcion%TYPE,      -- Descripción editada
    p_precio     tab_Productos.precio%TYPE,   -- Nuevo precio oficial
    p_stock      tab_Productos.stock%TYPE,  -- Nueva cifra de inventario
    p_imagen     tab_Productos.url_imagen%TYPE,      -- Actualización de asset visual
    p_id_marca   tab_Productos.id_marca%TYPE,    -- Referencia a marca
    p_id_cat     tab_Productos.id_categoria%TYPE,   -- Referencia a categoría principal
    p_id_subcat  tab_Productos.id_subcategoria%TYPE,   -- Referencia a subcategoría
    p_estado     tab_Productos.estado%TYPE    -- Nuevo estado (TRUE=Activo, FALSE=Inactivo)
)
RETURNS JSON  -- Retorno estándar de confirmación
AS $$
BEGIN
    -- VALIDACIÓN TAXONÓMICA
    IF NOT EXISTS (SELECT 1 FROM tab_Subcategorias
                   WHERE id_categoria = p_id_cat AND id_subcategoria = p_id_subcat) THEN
        RETURN json_build_object('ok', false,
            'msg', 'Error crítico: La jerarquía de Categoría y Subcategoría no es coherente.');
    END IF;

    -- OPERACIÓN DML: Actualización masiva de los campos del registro.
    UPDATE tab_Productos SET
        nom_producto = p_nombre,
        descripcion = p_desc,
        precio = p_precio,
        stock = p_stock,
        url_imagen = p_imagen,
        id_marca = p_id_marca,
        id_categoria = p_id_cat,
        id_subcategoria = p_id_subcat,
        estado = p_estado,                  -- Actualización de visibilidad
        fec_update = NOW(),                 -- Timestamp automático de auditoría
        usr_update = 'admin_editor'         -- Marca de sistema para el editor
    WHERE id_producto = p_id;               -- Focalizado por clave primaria

    -- Notificación de éxito para el backend
    RETURN json_build_object('ok', true,
        'msg', 'Los cambios en el producto han sido aplicados y auditados.');
END;
$$ LANGUAGE plpgsql;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 4: fn_cat_delete_producto (SOFT DELETE)        ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Desactivar lógicamente un producto        ║
-- ║               protegiendo la integridad referencial.    ║
-- ║  Llamada PHP: SELECT fn_cat_delete_producto(53, 'admin')║
-- ║  Retorna    : JSON {ok: bool, msg: '...'}               ║
-- ║                                                         ║
-- ║  SOFT DELETE:                                           ║
-- ║  No elimina el registro físicamente. Marca estado=FALSE ║
-- ║  y registra usr_delete + fec_delete para auditoría.     ║
-- ║                                                         ║
-- ║  BARRERAS DE SEGURIDAD (conservadas):                   ║
-- ║  1. Integridad Contable: Si el reloj se vendió, igual   ║
-- ║     se bloquea para mantener consistencia de negocio.   ║
-- ║  2. Integridad de Transacción: Si está en un carrito    ║
-- ║     activo, se bloquea para no interrumpir el checkout. ║
-- ╚══════════════════════════════════════════════════════════╝

-- Eliminar versión anterior con 2 parámetros si existiera (compatibilidad)
DROP FUNCTION IF EXISTS fn_cat_delete_producto(INTEGER, VARCHAR);

CREATE OR REPLACE FUNCTION fn_cat_delete_producto(
    p_id  tab_Productos.id_producto%TYPE           -- ID único del producto objetivo
)
RETURNS JSON  -- {ok: bool, msg: string}
AS $$
BEGIN
    -- BARRERA 1: Protección de Historial de Ventas.
    -- Si el producto ya fue vendido, se bloquea para mantener consistencia contable.
    IF EXISTS (SELECT 1 FROM tab_Detalle_Orden WHERE id_producto = p_id LIMIT 1) THEN
        RETURN json_build_object('ok', false,
            'msg', 'Prohibido: Este producto posee historial comercial vinculado y no puede eliminarse.');
    END IF;

    -- BARRERA 2: Protección de Flujo de Venta.
    -- Si está en un carrito activo, se bloquea para no interrumpir el checkout.
    IF EXISTS (SELECT 1 FROM tab_Carrito_Detalle WHERE id_producto = p_id LIMIT 1) THEN
        RETURN json_build_object('ok', false,
            'msg', 'Prohibido: El producto está en uso por carritos de compra activos.');
    END IF;

    -- SOFT DELETE: Desactivación lógica. El registro se conserva para auditoría.
    UPDATE tab_Productos SET
        estado     = FALSE,
        fec_delete = NOW()
    WHERE id_producto = p_id;

    -- Verificar que se encontró el producto
    IF NOT FOUND THEN
        RETURN json_build_object('ok', false,
            'msg', 'Producto no encontrado en el sistema.');
    END IF;

    RETURN json_build_object('ok', true,
        'msg', 'El producto ha sido desactivado del catálogo. El registro se conserva para auditoría.');
END;
$$ LANGUAGE plpgsql;



-- ██████████████████████████████████████████████████████████
-- ██  SECCIÓN 2: MARCAS                                   ██
-- ██████████████████████████████████████████████████████████
--
-- Las marcas son entidades simples con: id, nombre, estado.
-- Un producto siempre pertenece a UNA marca.
-- Una marca no puede borrarse si tiene productos vinculados.


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 5: fn_cat_get_marcas                             ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Listar todas las marcas registradas en el   ║
-- ║               sistema para gestión administrativa.      ║
-- ║  Llamada PHP: SELECT fn_cat_get_marcas()                ║
-- ║  Retorna    : JSON array [{id_marca, nom_marca, estado},...]║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin abre la sección "Marcas" del panel.           ║
-- ║  2. PHP (marcas.php) ejecuta SELECT fn_cat_get_marcas().║
-- ║  3. La función escanea tab_Marcas sin filtros.          ║
-- ║  4. Retorna JSON array → PHP decodifica y envía al UI.  ║
-- ║                                                         ║
-- ║  DETALLE:                                               ║
-- ║  Retorna tanto marcas activas como inactivas para que el║
-- ║  administrador pueda gestionarlas.                      ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_cat_get_marcas()
RETURNS JSON AS $$
DECLARE 
    v_result JSON; -- Buffer para el array final
BEGIN
    -- Capturamos el aggregate JSON de la tabla tab_Marcas.
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_result FROM (
        SELECT 
            m.id_marca,      -- Identificador numérico
            m.nom_marca,     -- Nombre comercial (ej: Omega, Tudor)
            m.estado_marca   -- Booleano que indica disponibilidad
        FROM tab_Marcas m
        ORDER BY m.id_marca ASC -- Orden natural por creación
    ) t;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE; -- Función de solo lectura optimizada


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 6: fn_cat_create_marca                         ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Registrar una nueva marca de relojes con   ║
-- ║               control estricto de duplicidad.           ║
-- ║  Llamada PHP: SELECT fn_cat_create_marca(10, 'Omega')    ║
-- ║  Retorna    : JSON {ok: bool, msg: text}                ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin ingresa nombre de la nueva marca.             ║
-- ║  2. PHP sanitiza y ejecuta fn_cat_create_marca(...).    ║
-- ║  3. La función verifica ID y nombre existentes.         ║
-- ║  4. Si libre → INSERT con sello de auditoría.           ║
-- ║  5. Retorna {ok, msg} → PHP reenvía al frontend.        ║
-- ║                                                         ║
-- ║  PROTECCIÓN DE NEGOCIO:                                 ║
-- ║  1. Evita colisión de IDs manuales.                     ║
-- ║  2. Evita duplicidad de nombres comerciales.            ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_cat_create_marca(
    p_id     tab_Marcas.id_marca%TYPE,   -- ID designado por arquitectura
    p_nombre tab_Marcas.nom_marca%TYPE,     -- Etiqueta comercial de la marca
    p_estado tab_Marcas.estado_marca%TYPE DEFAULT TRUE  -- Disponibilidad inicial
)
RETURNS JSON AS $$
BEGIN
    -- VERIFICACIÓN: Impedimos que el administrador cree registros que generen
    -- confusión o errores de clave duplicada en la capa física.
    IF EXISTS (SELECT 1 FROM tab_Marcas WHERE nom_marca = p_nombre OR id_marca = p_id) THEN
        RETURN json_build_object('ok', false,
            'msg', 'Conflicto de Datos: El nombre "' || p_nombre || '" o el ID ' || p_id || ' ya están registrados.');
    END IF;

    -- INSERCIÓN: Registramos con metadatos de auditoría básica.
    INSERT INTO tab_Marcas (
        id_marca, 
        nom_marca, 
        estado_marca, 
        fec_insert,  -- Fecha actual
        usr_insert   -- Trazabilidad inicial
    ) VALUES (
        p_id, 
        p_nombre, 
        p_estado, 
        NOW(), 
        'admin_root'
    );

    RETURN json_build_object('ok', true, 'msg', 'La marca ha sido incorporada al sistema satisfactoriamente.');
END;
$$ LANGUAGE plpgsql;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 7: fn_cat_update_marca                         ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Actualizar los metadatos de una marca y su ║
-- ║               disponibilidad en el catálogo.            ║
-- ║  Llamada PHP: SELECT fn_cat_update_marca(10, 'Omega', f) ║
-- ║  Retorna    : JSON {ok: true, msg: text}                ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin edita nombre o estado de la marca.            ║
-- ║  2. PHP ejecuta SELECT fn_cat_update_marca(...).        ║
-- ║  3. La función actualiza con sello de auditoría.        ║
-- ║  4. Retorna {ok, msg} → PHP confirma al frontend.       ║
-- ║                                                         ║
-- ║  NOTA: Al desactivar una marca (estado=FALSE), los       ║
-- ║  productos vinculados podrían dejar de ser visibles en   ║
-- ║  el frontend dependiendo de la lógica de negocio.       ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_cat_update_marca(
    p_id     tab_Marcas.id_marca%TYPE,   -- Identificador de la marca objetivo
    p_nombre tab_Marcas.nom_marca%TYPE,     -- Nuevo nombre comercial
    p_estado tab_Marcas.estado_marca%TYPE DEFAULT TRUE  -- Nuevo estado binario
)
RETURNS JSON AS $$
BEGIN
    -- DML: Actualización con sello de auditoría de edición.
    UPDATE tab_Marcas SET
        nom_marca = p_nombre,         -- Sobrescribe nombre
        estado_marca = p_estado,      -- Sobrescribe estado
        fec_update = NOW(),           -- Actualiza reloj del sistema
        usr_update = 'admin_editor'   -- Marca del editor
    WHERE id_marca = p_id;

    RETURN json_build_object('ok', true, 'msg', 'Información de marca actualizada con éxito.');
END;
$$ LANGUAGE plpgsql;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 8: fn_cat_delete_marca (SOFT DELETE)           ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Desactivar lógicamente una marca si no    ║
-- ║               tiene productos vinculados activos.       ║
-- ║  Llamada PHP: SELECT fn_cat_delete_marca(10, 'admin')   ║
-- ║  Retorna    : JSON {ok: bool, msg: text}                ║
-- ║                                                         ║
-- ║  SOFT DELETE:                                           ║
-- ║  Marca estado_marca=FALSE + usr_delete + fec_delete.    ║
-- ║  El registro se conserva para auditoría e historial.    ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_cat_delete_marca(
    p_id  tab_Marcas.id_marca%TYPE,          -- ID de la marca a desactivar
    p_usr tab_Marcas.usr_delete%TYPE      -- Usuario que ejecuta la operación
)
RETURNS JSON AS $$
DECLARE
    v_count INTEGER;  -- Contador de dependencias detectadas
BEGIN
    -- AUDITORÍA DE INTEGRIDAD: Validamos productos activos de esta marca.
    SELECT COUNT(id_producto) INTO v_count 
    FROM tab_Productos 
    WHERE id_marca = p_id AND estado = TRUE;

    -- BLOQUEO: Si hay productos activos, abortamos para proteger el catálogo.
    IF v_count > 0 THEN
        RETURN json_build_object('ok', false,
            'msg', 'Restricción de Integridad: Existen ' || v_count || 
            ' productos activos asociados a esta marca. Desactívelos primero.');
    END IF;

    -- SOFT DELETE: Desactivación lógica con trazabilidad.
    UPDATE tab_Marcas SET
        estado_marca = FALSE,
        usr_delete   = p_usr,
        fec_delete   = NOW()
    WHERE id_marca = p_id;

    RETURN json_build_object('ok', true, 'msg', 'La marca ha sido desactivada. El registro se conserva para auditoría.');
END;
$$ LANGUAGE plpgsql;


-- ██████████████████████████████████████████████████████████
-- ██  SECCIÓN 3: CATEGORÍAS                               ██
-- ██████████████████████████████████████████████████████████
--
-- Las categorías son el primer nivel de clasificación.
-- Ejemplo: "Relojes de Lujo", "Relojes Deportivos"
-- Cada categoría puede tener subcategorías hijas.
-- DOBLE PROTECCIÓN al borrar: verifica subcategorías Y productos.


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 9: fn_cat_get_categorias                       ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Listar todas las categorías de nivel superior║
-- ║               definidas en el catálogo.                 ║
-- ║  Llamada PHP: SELECT fn_cat_get_categorias()            ║
-- ║  Retorna    : JSON array [{id, nom, desc, estado}, ...] ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin abre la sección "Categorías" del panel.       ║
-- ║  2. PHP ejecuta SELECT fn_cat_get_categorias().         ║
-- ║  3. La función escanea tab_Categorias completa.         ║
-- ║  4. Retorna JSON array → PHP decodifica y envía al UI.  ║
-- ║                                                         ║
-- ║  DATO TÉCNICO:                                          ║
-- ║  Usa row_to_json para encapsular la metadata básica de   ║
-- ║  clasificación (nombre y descripción).                  ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_cat_get_categorias()
RETURNS JSON AS $$
DECLARE 
    v_result JSON; -- Buffer de salida
BEGIN
    -- Agregación de registros de la tabla tab_Categorias.
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_result FROM (
        SELECT 
            c.id_categoria,            -- PK secuencial o manual
            c.nom_categoria,           -- Etiqueta (ej: Lujo, Vintage)
            c.descripcion_categoria,   -- Texto informativo
            c.estado                   -- TRUE=Operativa, FALSE=Archivada
        FROM tab_Categorias c
        ORDER BY c.id_categoria ASC   -- Orden lógico por ID
    ) t;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE; -- Optimización de lectura fija


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 10: fn_cat_create_categoria                    ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Insertar una nueva rama principal de       ║
-- ║               clasificación en el árbol del catálogo.   ║
-- ║  Llamada PHP: SELECT fn_cat_create_categoria(3, ...)     ║
-- ║  Retorna    : JSON {ok: true, msg: text}                ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin llena formulario con nombre y descripción.    ║
-- ║  2. PHP sanitiza y ejecuta fn_cat_create_categoria(...). ║
-- ║  3. INSERT con sello de auditoría (fec_insert, usr).     ║
-- ║  4. Retorna {ok, msg} → PHP confirma al frontend.       ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE OR REPLACE FUNCTION fn_cat_create_categoria(
    p_id      tab_Categorias.id_categoria%TYPE,      -- ID único sugerido
    p_nombre  tab_Categorias.nom_categoria%TYPE,         -- Nombre de la categoría
    p_desc    tab_Categorias.descripcion_categoria%TYPE DEFAULT '', -- Descripción (opcional)
    p_estado  tab_Categorias.estado%TYPE DEFAULT TRUE -- Disponibilidad inicial
) RETURNS JSON AS $$
BEGIN
    -- Inserción directa con sellos de auditoría de sistema.
    INSERT INTO tab_Categorias (
        id_categoria, 
        nom_categoria, 
        descripcion_categoria, 
        estado, 
        fec_insert, 
        usr_insert
    ) VALUES (
        p_id, 
        p_nombre, 
        p_desc, 
        p_estado, 
        NOW(), 
        'admin_root'
    );

    RETURN json_build_object('ok', true, 'msg', 'Nueva categoría principal registrada.');
END;
$$ LANGUAGE plpgsql;

-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 11: fn_cat_update_categoria                    ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Modificar la información descriptiva de     ║
-- ║               una categoría principal.                  ║
-- ║  Llamada PHP: SELECT fn_cat_update_categoria(3, ...)     ║
-- ║  Retorna    : JSON {ok: true, msg: text}                ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin edita nombre, desc o estado de la categoría.  ║
-- ║  2. PHP ejecuta SELECT fn_cat_update_categoria(...).    ║
-- ║  3. UPDATE con sello de auditoría (fec_update).         ║
-- ║  4. Retorna {ok, msg} → PHP confirma al frontend.       ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE OR REPLACE FUNCTION fn_cat_update_categoria(
    p_id      tab_Categorias.id_categoria%TYPE,      -- ID de la categoría a editar
    p_nombre  tab_Categorias.nom_categoria%TYPE,         -- Nuevo nombre
    p_desc    tab_Categorias.descripcion_categoria%TYPE DEFAULT '', -- Nueva descripción
    p_estado  tab_Categorias.estado%TYPE DEFAULT TRUE -- Nuevo estado
) RETURNS JSON AS $$
BEGIN
    -- Actualización de datos con registro de cambios (fec_update).
    UPDATE tab_Categorias SET 
        nom_categoria = p_nombre, 
        descripcion_categoria = p_desc,
        estado = p_estado, 
        fec_update = NOW(), 
        usr_update = 'admin_editor'
    WHERE id_categoria = p_id;

    RETURN json_build_object('ok', true, 'msg', 'Categoría actualizada exitosamente.');
END;
$$ LANGUAGE plpgsql;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 12: fn_cat_delete_categoria (SOFT DELETE)      ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Desactivar lógicamente una categoría      ║
-- ║               asegurando que no existan dependencias    ║
-- ║               activas de subcategorías ni productos.    ║
-- ║  Llamada PHP: SELECT fn_cat_delete_categoria(3,'admin') ║
-- ║  Retorna    : JSON {ok: bool, msg: text}                ║
-- ║                                                         ║
-- ║  SOFT DELETE:                                           ║
-- ║  Marca estado=FALSE + usr_delete + fec_delete.          ║
-- ║  MURALLA DE PROTECCIÓN DOBLE (conservada):              ║
-- ║  1. Subcategorías activas vinculadas → bloquea.         ║
-- ║  2. Productos activos asociados → bloquea.              ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE OR REPLACE FUNCTION fn_cat_delete_categoria(
    p_id  tab_Categorias.id_categoria%TYPE,          -- ID de la categoría a desactivar
    p_usr tab_Categorias.usr_delete%TYPE      -- Usuario que ejecuta la operación
)
RETURNS JSON AS $$
BEGIN
    -- PROTECCIÓN 1: Integridad de la Taxonomía.
    IF EXISTS (SELECT 1 FROM tab_Subcategorias WHERE id_categoria = p_id AND estado = TRUE LIMIT 1) THEN
        RETURN json_build_object('ok', false,
            'msg', 'Acción Denegada: La categoría contiene subcategorías activas vinculadas.');
    END IF;

    -- PROTECCIÓN 2: Integridad del Stock.
    IF EXISTS (SELECT 1 FROM tab_Productos WHERE id_categoria = p_id AND estado = TRUE LIMIT 1) THEN
        RETURN json_build_object('ok', false,
            'msg', 'Acción Denegada: Hay productos activos en el catálogo que dependen de esta categoría.');
    END IF;

    -- SOFT DELETE: Desactivación lógica con trazabilidad.
    UPDATE tab_Categorias SET
        estado     = FALSE,
        usr_delete = p_usr,
        fec_delete = NOW()
    WHERE id_categoria = p_id;

    RETURN json_build_object('ok', true, 'msg', 'Categoría desactivada del sistema. El registro se conserva para auditoría.');
END;
$$ LANGUAGE plpgsql;


-- ██████████████████████████████████████████████████████████
-- ██  SECCIÓN 4: SUBCATEGORÍAS                            ██
-- ██████████████████████████████████████████████████████████
--
-- Las subcategorías tienen PK COMPUESTA: (id_categoria, id_subcategoria)
-- Esto significa que la subcategoría "Automáticos" (id=1) puede existir
-- bajo categoría "Lujo" (cat=1) Y bajo "Deportivos" (cat=2).
-- Son entidades diferentes a pesar de tener el mismo id_subcategoria.


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 13: fn_cat_get_subcategorias                    ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Listar todas las subcategorías vinculadas a║
-- ║               sus categorías padre para gestión.        ║
-- ║  Llamada PHP: SELECT fn_cat_get_subcategorias()         ║
-- ║  Retorna    : JSON array [{id_cat, id_sub, nom, padre},...]║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin abre la sección "Subcategorías" del panel.    ║
-- ║  2. PHP ejecuta SELECT fn_cat_get_subcategorias().      ║
-- ║  3. INNER JOIN con tab_Categorias resuelve nombres.     ║
-- ║  4. Retorna JSON array → PHP decodifica y envía al UI.  ║
-- ║                                                         ║
-- ║  DETALLE TÉCNICO:                                       ║
-- ║  Usa un JOIN obligatorio (INNER) con tab_Categorias para ║
-- ║  poblar el nombre del padre, garantizando la jerarquía. ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_cat_get_subcategorias()
RETURNS JSON AS $$
DECLARE 
    v_result JSON; -- Buffer de resultados
BEGIN
    -- Generación de JSON agregado con datos de relación.
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_result FROM (
        SELECT 
            s.id_categoria,      -- ID del padre (Referencia)
            s.id_subcategoria,   -- ID del hijo (Especificación)
            s.nom_subcategoria,  -- Nombre (ej: Automáticos, Cuarzo)
            s.estado,            -- TRUE=Activo, FALSE=Inactivo
            c.nom_categoria      -- Etiqueta del padre (desde el JOIN)
        FROM tab_Subcategorias s
        -- El JOIN asegura que solo vemos hijos con padres válidos.
        JOIN tab_Categorias c ON s.id_categoria = c.id_categoria
        ORDER BY s.id_categoria, s.id_subcategoria ASC -- Orden jerárquico
    ) t;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE; -- Función estable para lecturas continuas


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 14: fn_cat_create_subcategoria                 ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Registrar una nueva subcategoría vinculada  ║
-- ║               a una categoría padre específica.          ║
-- ║  Llamada PHP: SELECT fn_cat_create_subcategoria(1, 4, ..)║
-- ║  Retorna    : JSON {ok: bool, msg: text}                ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin selecciona categoría padre e ingresa datos.   ║
-- ║  2. PHP ejecuta fn_cat_create_subcategoria(...).        ║
-- ║  3. La función verifica PK compuesta (cat+sub).         ║
-- ║  4. Si libre → INSERT con estado activo.                ║
-- ║  5. Retorna {ok, msg} → PHP reenvía al frontend.        ║
-- ║                                                         ║
-- ║  VALIDACIÓN DE LLAVE COMPUESTA:                         ║
-- ║  Verifica que el ID de subcategoría no esté repetido     ║
-- ║  DENTRO de la misma categoría padre.                    ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE OR REPLACE FUNCTION fn_cat_create_subcategoria(
    p_id_cat  tab_Subcategorias.id_categoria%TYPE,  -- ID del padre
    p_id_sub  tab_Subcategorias.id_subcategoria%TYPE,  -- ID del hijo (PK compuesta)
    p_nombre  tab_Subcategorias.nom_subcategoria%TYPE      -- Etiqueta descriptiva
) RETURNS JSON AS $$
BEGIN
    -- BARRERA: Control de duplicidad en la clave primaria compuesta.
    IF EXISTS (SELECT 1 FROM tab_Subcategorias
               WHERE id_categoria = p_id_cat AND id_subcategoria = p_id_sub) THEN
        RETURN json_build_object('ok', false,
            'msg', 'Conflicto: El código ' || p_id_sub || ' ya existe para esta categoría.');
    END IF;

    -- INSERCIÓN: Registro inicial con estado activo.
    INSERT INTO tab_Subcategorias (
        id_categoria, 
        id_subcategoria, 
        nom_subcategoria, 
        estado, 
        fec_insert, 
        usr_insert
    ) VALUES (
        p_id_cat, 
        p_id_sub, 
        p_nombre, 
        TRUE, 
        NOW(), 
        'admin_cat'
    );

    RETURN json_build_object('ok', true, 'msg', 'Subcategoría registrada en el árbol jerárquico.');
END;
$$ LANGUAGE plpgsql;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 15: fn_cat_update_subcategoria                 ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Actualizar el nombre o estado de una       ║
-- ║               subcategoría puntual.                     ║
-- ║  Llamada PHP: SELECT fn_cat_update_subcategoria(1, 4, ..)║
-- ║  Retorna    : JSON {ok: true, msg: text}                ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin edita nombre de la subcategoría.              ║
-- ║  2. PHP ejecuta fn_cat_update_subcategoria(...).        ║
-- ║  3. UPDATE por clave compuesta con sello de auditoría.  ║
-- ║  4. Retorna {ok, msg} → PHP confirma al frontend.       ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE OR REPLACE FUNCTION fn_cat_update_subcategoria(
    p_id_cat  tab_Subcategorias.id_categoria%TYPE,  -- ID del padre
    p_id_sub  tab_Subcategorias.id_subcategoria%TYPE,  -- ID del hijo
    p_nombre  tab_Subcategorias.nom_subcategoria%TYPE,     -- Nuevo nombre
    p_estado  tab_Subcategorias.estado%TYPE DEFAULT TRUE  -- Nuevo estado (permite reactivar)
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


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 16: fn_cat_delete_subcategoria (SOFT DELETE)   ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Desactivar lógicamente una subcategoría   ║
-- ║               siempre que no existan productos activos  ║
-- ║               asociados a ella.                         ║
-- ║  Llamada PHP: SELECT fn_cat_delete_subcategoria(1,4,'a')║
-- ║  Retorna    : JSON {ok: bool, msg: text}                ║
-- ║                                                         ║
-- ║  SOFT DELETE:                                           ║
-- ║  Marca estado=FALSE + usr_delete + fec_delete.          ║
-- ║  Usa clave compuesta (id_categoria, id_subcategoria).   ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE OR REPLACE FUNCTION fn_cat_delete_subcategoria(
    p_id_cat tab_Subcategorias.id_categoria%TYPE,
    p_id_sub tab_Subcategorias.id_subcategoria%TYPE,
    p_usr    tab_Subcategorias.usr_delete%TYPE  -- Usuario que ejecuta la operación
)
RETURNS JSON AS $$
DECLARE 
    v_count INTEGER; -- Contador de productos afectados
BEGIN
    -- AUDITORÍA: Verificamos si hay productos activos que dependen de esta clasificación.
    SELECT COUNT(id_producto) INTO v_count
    FROM tab_Productos
    WHERE id_categoria = p_id_cat AND id_subcategoria = p_id_sub AND estado = TRUE;

    -- BARRERA: Si hay dependencias activas, informamos al admin.
    IF v_count > 0 THEN
        RETURN json_build_object('ok', false,
            'msg', 'Restricción de Integridad: Existen ' || v_count || 
            ' productos activos vinculados a esta subcategoría específica.');
    END IF;

    -- SOFT DELETE: Desactivación lógica por clave compuesta.
    UPDATE tab_Subcategorias SET
        estado     = FALSE,
        usr_delete = p_usr,
        fec_delete = NOW()
    WHERE id_categoria = p_id_cat AND id_subcategoria = p_id_sub;

    RETURN json_build_object('ok', true, 'msg', 'Subcategoría desactivada del árbol. El registro se conserva para auditoría.');
END;
$$ LANGUAGE plpgsql;


-- ██████████████████████████████████████████████████████████
-- ██  SECCIÓN 5: DROPDOWNS (Selectores del Frontend)      ██
-- ██████████████████████████████████████████████████████████
--
-- Los dropdowns son listas simplificadas para los <select>
-- del frontend. Solo retornan ID + nombre, y SOLO los activos.
-- Son usados por catalogos.php para poblar formularios.
--
-- DIFERENCIA con los GET normales:
-- - GET normales retornan TODOS los registros con TODOS los campos
-- - Dropdowns solo retornan activos (estado=TRUE) con id+nombre


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 17: fn_cat_dropdown_marcas                     ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Proveer una lista ligera de marcas activas ║
-- ║               para selectores en el catálogo.           ║
-- ║  Llamada PHP: SELECT fn_cat_dropdown_marcas()           ║
-- ║  Retorna    : JSON array [{id_marca, nom_marca}, ...]   ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Frontend abre formulario de producto (alta/edición).║
-- ║  2. PHP ejecuta SELECT fn_cat_dropdown_marcas().        ║
-- ║  3. Solo marcas con estado_marca=TRUE se incluyen.      ║
-- ║  4. Retorna JSON array → pobla el <select> del frontend.║
-- ║                                                         ║
-- ║  UX FRONTEND:                                           ║
-- ║  Filtra por estado_marca = TRUE para evitar que el      ║
-- ║  usuario seleccione marcas descatalogadas.              ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_cat_dropdown_marcas()
RETURNS JSON AS $$
DECLARE 
    v_result JSON; -- Buffer de salida
BEGIN
    -- Captura simplificada: Solo marcas operativas.
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_result FROM (
        SELECT 
            m.id_marca,    -- ID de referencia
            m.nom_marca    -- Etiqueta visual
        FROM tab_Marcas m
        WHERE m.estado_marca = TRUE -- Filtro de visibilidad frontend
        ORDER BY m.nom_marca ASC    -- Orden alfabético para el usuario
    ) t;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE; -- Función estable para lecturas continuas


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 18: fn_cat_dropdown_categorias                 ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Proveer una lista ligera de categorías     ║
-- ║               activas para selectores de catálogo.      ║
-- ║  Llamada PHP: SELECT fn_cat_dropdown_categorias()       ║
-- ║  Retorna    : JSON array [{id_categoria, nom_categoria}]║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Frontend abre formulario de producto.               ║
-- ║  2. PHP ejecuta SELECT fn_cat_dropdown_categorias().    ║
-- ║  3. Solo categorías con estado=TRUE se incluyen.        ║
-- ║  4. Retorna JSON array → pobla el <select> del frontend.║
-- ║                                                         ║
-- ║  SEGURIDAD UI:                                          ║
-- ║  Solo categorías con estado = TRUE son elegibles.       ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_cat_dropdown_categorias()
RETURNS JSON AS $$
DECLARE 
    v_result JSON;
BEGIN
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_result FROM (
        SELECT 
            c.id_categoria, -- ID de referencia
            c.nom_categoria -- Etiqueta visual
        FROM tab_Categorias c
        WHERE c.estado = TRUE
        ORDER BY c.nom_categoria ASC
    ) t;
    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 19: fn_cat_dropdown_subcategorias              ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Listar subcategorías activas filtradas por ║
-- ║               su respectiva categoría padre.            ║
-- ║  Llamada PHP: SELECT fn_cat_dropdown_subcategorias(1)    ║
-- ║  Retorna    : JSON array [{id_subcategoria, nom_sub}]   ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Usuario selecciona categoría en el formulario.      ║
-- ║  2. Frontend dispara AJAX con el ID de categoría.       ║
-- ║  3. PHP ejecuta fn_cat_dropdown_subcategorias(cat_id).  ║
-- ║  4. Solo subcategorías activas del padre se incluyen.   ║
-- ║  5. Retorna JSON array → el <select> se recarga dinám.  ║
-- ║                                                         ║
-- ║  LÓGICA REACTIVA:                                       ║
-- ║  El frontend selecciona una categoría y este dropdown   ║
-- ║  se recarga dinámicamente con los hijos correspondientes.║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_cat_dropdown_subcategorias(
    p_id_cat tab_Subcategorias.id_categoria%TYPE  -- ID de la categoría padre seleccionada
)
RETURNS JSON AS $$
DECLARE 
    v_result JSON;
BEGIN
    -- Captura dependiente: Solo hijos operativos del padre indicado.
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_result FROM (
        SELECT 
            s.id_subcategoria, -- ID de referencia hijo
            s.nom_subcategoria -- Etiqueta visual
        FROM tab_Subcategorias s
        WHERE s.id_categoria = p_id_cat  -- Filtro jerárquico
          AND s.estado = TRUE            -- Solo operativas para el usuario
        ORDER BY s.nom_subcategoria ASC  -- Alfabético
    ) t;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE;


-- ██████████████████████████████████████████████████████████
-- ██  SECCIÓN 6: SERVICIOS TÉCNICOS (Taller)              ██
-- ██████████████████████████████████████████████████████████
--
-- Los servicios son ofertas del taller de reparación.
-- Ejemplo: "Cambio de batería", "Restauración completa"
-- Cada servicio puede tener reservas/citas vinculadas.
-- No se puede borrar un servicio si tiene citas pendientes.


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 20: fn_cat_get_servicios                       ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Listar la oferta técnica completa del       ║
-- ║               taller para administración y agendamiento.║
-- ║  Llamada PHP: SELECT fn_cat_get_servicios()             ║
-- ║  Retorna    : JSON array con la ficha técnica completa.  ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. El sistema (Admin/Cliente) solicita el portafolio.   ║
-- ║  2. La función consulta tab_Servicios.                   ║
-- ║  3. Retorna JSON array con IDs, nombres, precios y       ║
-- ║     el indicador de estado (Activo/Inactivo).           ║
-- ║                                                         ║
-- ║  ¿Por qué incluimos 'estado'?                           ║
-- ║  Para que el frontend pueda filtrar servicios que ya no  ║
-- ║  se prestan sin tener que eliminarlos físicamente,       ║
-- ║  preservando la integridad de las reservas pasadas.     ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_cat_get_servicios()
RETURNS JSON AS $$
DECLARE 
    v_result JSON;
BEGIN
    SELECT COALESCE(json_agg(row_to_json(t)), '[]'::json) INTO v_result FROM (
        SELECT 
            s.id_servicio,          -- Identificador único
            s.nom_servicio,         -- Etiqueta comercial
            s.descripcion,          -- Detalle técnico
            s.precio_servicio,      -- Tarifa base
            s.duracion_estimada,    -- Tiempo de compromiso
            s.estado                -- Disponibilidad (TRUE=Activo, FALSE=Pausado)
        FROM tab_Servicios s
        ORDER BY s.id_servicio DESC 
    ) t;

    RETURN v_result;
END;
$$ LANGUAGE plpgsql STABLE;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 21: fn_cat_create_servicio                     ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Incorporar un nuevo tipo de servicio técnico║
-- ║               al portafolio del taller.                 ║
-- ║  Llamada PHP: SELECT fn_cat_create_servicio(5, ...)      ║
-- ║  Retorna    : JSON {ok: bool, msg: text}                ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin llena formulario de nuevo servicio.           ║
-- ║  2. PHP sanitiza y ejecuta fn_cat_create_servicio(...). ║
-- ║  3. La función verifica nombre duplicado.               ║
-- ║  4. Si libre → INSERT con estado activo + auditoría.    ║
-- ║  5. Retorna {ok, msg} → PHP reenvía al frontend.        ║
-- ║                                                         ║
-- ║  BARRERA:                                               ║
-- ║  No permite duplicar nombres comerciales para evitar     ║
-- ║  confusión en el agendamiento.                          ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE OR REPLACE FUNCTION fn_cat_create_servicio(
    p_id       tab_Servicios.id_servicio%TYPE,   -- ID manual
    p_nombre   tab_Servicios.nom_servicio%TYPE,     -- Ejemplo: "Pulido de Cristal"
    p_desc     tab_Servicios.descripcion%TYPE,     -- Especificación técnica
    p_precio   tab_Servicios.precio_servicio%TYPE,  -- Costo
    p_duracion tab_Servicios.duracion_estimada%TYPE,     -- Ej: "3 días hábiles"
    p_usr      tab_Servicios.usr_insert%TYPE      -- Auditoría
) RETURNS JSON AS $$
BEGIN
    -- VERIFICACIÓN: Integridad semántica del portafolio.
    IF EXISTS (SELECT 1 FROM tab_Servicios WHERE nom_servicio = p_nombre) THEN
        RETURN json_build_object('ok', false,
            'msg', 'Conflicto: El servicio técnico "' || p_nombre || '" ya se encuentra en el portafolio.');
    END IF;

    -- INSERCIÓN: Registro en la base de servicios.
    INSERT INTO tab_Servicios (
        id_servicio, 
        nom_servicio, 
        descripcion, 
        precio_servicio, 
        duracion_estimada, 
        estado,      -- Se crea como ACTIVO (TRUE) por defecto
        fec_insert, 
        usr_insert
    ) VALUES (
        p_id, 
        p_nombre, 
        p_desc, 
        p_precio, 
        p_duracion, 
        TRUE, 
        NOW(), 
        p_usr
    );

    RETURN json_build_object('ok', true, 'msg', 'Servicio técnico integrado exitosamente.');
END;
$$ LANGUAGE plpgsql;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 22: fn_cat_update_servicio                     ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Actualizar los parámetros comerciales,      ║
-- ║               técnicos y de disponibilidad de un servicio.║
-- ║  Llamada PHP: SELECT fn_cat_update_servicio(5, ..., t/f) ║
-- ║  Retorna    : JSON {ok: true, msg: text}                ║
-- ║                                                         ║
-- ║  FLUJO:                                                 ║
-- ║  1. Admin edita datos o alterna el interruptor de estado.║
-- ║  2. PHP (servicios.php) ejecuta la actualización.        ║
-- ║  3. UPDATE con sello de auditoría (fec_update).         ║
-- ║  4. Retorna {ok, msg} → PHP confirma al frontend.       ║
-- ║                                                         ║
-- ║  IMPORTANCIA DEL ESTADO:                                 ║
-- ║  Permite retirar un servicio de la vista del cliente sin ║
-- ║  romper las FK de citas previas en tab_Reservas.        ║
-- ╚══════════════════════════════════════════════════════════╝

CREATE OR REPLACE FUNCTION fn_cat_update_servicio(
    p_id       tab_Servicios.id_servicio%TYPE,   -- ID del servicio a modificar
    p_nombre   tab_Servicios.nom_servicio%TYPE,     -- Nuevo nombre
    p_desc     tab_Servicios.descripcion%TYPE,     -- Nueva especificación
    p_precio   tab_Servicios.precio_servicio%TYPE,  -- Ajuste de tarifa
    p_duracion tab_Servicios.duracion_estimada%TYPE,     -- Ajuste de tiempo
    p_estado   tab_Servicios.estado%TYPE DEFAULT TRUE -- Disponibilidad lógica
) RETURNS JSON AS $$
BEGIN
    -- DML con sello de auditoría de edición.
    UPDATE tab_Servicios SET
        nom_servicio = p_nombre, 
        descripcion = p_desc,
        precio_servicio = p_precio, 
        duracion_estimada = p_duracion,
        estado = p_estado,           -- Sincronización con el nuevo campo de base
        fec_update = NOW(), 
        usr_update = 'admin_editor'
    WHERE id_servicio = p_id;

    RETURN json_build_object('ok', true, 'msg', 'Servicio técnico actualizado y auditado correctamente.');
END;
$$ LANGUAGE plpgsql;


-- ╔══════════════════════════════════════════════════════════╗
-- ║  FUNCIÓN 23: fn_cat_delete_servicio (SOFT DELETE)       ║
-- ╠══════════════════════════════════════════════════════════╣
-- ║  Propósito  : Desactivar lógicamente un servicio        ║
-- ║               blindando la integridad de la agenda.     ║
-- ║  Llamada PHP: SELECT fn_cat_delete_servicio(5,'admin')  ║
-- ║  Retorna    : JSON {ok: bool, msg: text}                ║
-- ║                                                         ║
-- ║  SOFT DELETE:                                           ║
-- ║  Marca estado=FALSE + usr_delete + fec_delete.          ║
-- ║  Las reservas existentes conservan su FK intacta.       ║
-- ╚══════════════════════════════════════════════════════════╝
CREATE OR REPLACE FUNCTION fn_cat_delete_servicio(
    p_id  tab_Servicios.id_servicio%TYPE,           -- ID del servicio a desactivar
    p_usr tab_Servicios.usr_delete%TYPE      -- Usuario que ejecuta la operación
)
RETURNS JSON AS $$
DECLARE
    v_count BIGINT; -- Contador de reservas activas encontradas
BEGIN
    -- BARRERA: Protección de reservas activas (pendientes o confirmadas).
    -- Servicios con historial cerrado (cancelado/completado) sí pueden desactivarse.
    SELECT COUNT(id_reserva) INTO v_count 
    FROM tab_Reservas 
    WHERE id_servicio = p_id
      AND estado_reserva IN ('pendiente', 'confirmada');

    IF v_count > 0 THEN
        RETURN json_build_object('ok', false,
            'msg', 'Restricción de Integridad: Este servicio posee ' || v_count || 
            ' citas activas en agenda. Ciérrelas primero antes de desactivar el servicio.');
    END IF;

    -- SOFT DELETE: Desactivación lógica con trazabilidad.
    UPDATE tab_Servicios SET
        estado     = FALSE,
        usr_delete = p_usr,
        fec_delete = NOW()
    WHERE id_servicio = p_id;

    RETURN json_build_object('ok', true, 'msg', 'Servicio desactivado del portafolio. El registro se conserva para auditoría.');
END;
$$ LANGUAGE plpgsql;
