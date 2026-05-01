x# 🧠 Memoria del Proyecto - RD_WATCH

Este documento mantiene un registro persistente del contexto, decisiones globales, problemas y estado actual del ecosistema RD_WATCH. Al iniciar cualquier sesión, este es el primer archivo que debe consultarse.

---

## 🎯 1. Objetivo Principal
- **Visión General:** RD_WATCH es una eCommerce orientada al lujo y la "Alta Relojería" interactiva con venta de productos y prestación de servicios mecánicos.
- **Enfoque técnico:** Se asume un producto premium mediante Vanilla HTML/JS/CSS, evitando frameworks innecesarios en frontend para mantener velocidad, y con APIs RESTful en PHP puro.

## 🏗️ 2. Stack Tecnológico Estructurado
- **Backend:** PHP. Integración de APIs alojadas en `src/backend/` controlando inventario, envíos y autenticación.
- **Frontend:** Vanilla Javascript + DOM Manipulation (`src/js/script.js`), CSS modular por archivo (`style.css`).
- **Base de Datos:** PostgreSQL. BD real se llama **`db_rdwatch`** (no `rdwatch`). Sistema de inicialización gestionado desde `install_db.bat`.

## 📜 3. Decisiones y Patrones Implementados
- **Arquitectura de Scripts DB (09/04/2026):** Se unificó el autoinstalador `install_db.bat`. Se aplicó de regla forzar bandera `--pset=pager=off` en todo el pipeline local en windows para que los resultados de queries masivos no congelen la terminal.
- **Comportamiento Bfcache del Navegador (09/04/2026):** En un entorno nativo sin estado reactivos (tipo React/Vue), el botón de «Atrás» del navegador recarga la vista conservando sus forms interactuables. Para corregir el checkout reteniendo la foto del último voucher, se adoptó el estándar de escuchar globalmente al evento `pageshow` y aplicar reseteo manual.
- **Herencia UI / Componentes CSS (09/04/2026):** Dado que se utiliza un mismo `<header>` sin componentes React, este perdía la legibilidad al scrollTop=0 en fondos blancos (vs fondo oscuro en Home). Se estableció el estándar CSS `.header--solid` para obligar fondo mate desde el momento de inicialización en páginas adyacentes (`factura.html` / subpáginas).
- **Funciones PostgreSQL Duplicadas (09/04/2026):** Los scripts de instalación se ejecutaron múltiples veces con firmas distintas (ej: parámetro `SMALLINT` vs `INTEGER`). Esto genera ambigüedad al hacer `SELECT fn_nombre(?)` desde PHP sin cast explícito. **REGLA:** Siempre usar casts explícitos en todas las llamadas PHP → `?::INTEGER`, `?::smallint`, `?::date`. Esta regla aplica a TODAS las APIs.
- **Encoding UTF-8 en PDO (09/04/2026):** Se agregó `options='--client-encoding=UTF8'` al DSN de PostgreSQL para eliminar doble-codificación de caracteres con tilde (mostraba `Atl\u00c3\u00a1ntico` en vez de `Atlántico`).
- **Resiliencia de Esquema con `%TYPE` (23/04/2026):** Todas las funciones PL/pgSQL fueron refactorizadas para anclar los tipos de datos de sus parámetros y variables `DECLARE` directamente a las tablas usando `%TYPE` (ej: `p_id tab_Usuarios.id_usuario%TYPE`). Esto garantiza que futuros cambios en la estructura de la base de datos (como pasar de `INTEGER` a `BIGINT`) no requieran actualizaciones manuales en el código del backend SQL.
- **Optimización de Rendimiento API (24/04/2026):** Se eliminó la doble serialización JSON redundante (`json_decode` + `json_encode`) en toda la capa de backend. Ahora las APIs PHP imprimen directamente el string JSON retornado por PostgreSQL, minimizando el uso de CPU y RAM del servidor.
- **Estandarización de Respuestas HTTP (24/04/2026):** Se implementaron códigos de estado HTTP estándar (ej: `400 Bad Request` para errores de validación) en lugar de retornar siempre `200 OK`. Esto permite que el frontend (Axios/Fetch) maneje las excepciones de red de forma nativa y robusta.
- **Rate Limits y Control de Citas (28/04/2026):** Se implementó control en solicitudes de citas del taller. El usuario puede solicitar **24/7**, pero las restricciones aplican a la **fecha seleccionada**: no domingos, mínimo 2 días de anticipación, máx 10 citas por fecha. Rate limits por cliente: 1/día y 2/semana (por fecha de creación). Cancelación solo con 1 día de anticipación (clientes; admins sin restricción). Validación en 3 capas: PostgreSQL (autoritativa), PHP (anticipada) y Frontend (UX). Zona horaria forzada a `America/Bogota`. Solo citas `pendiente`/`confirmada` consumen cuota. Se usa `COUNT(1)` por estándar del proyecto.


## ⚠️ 4. Limitaciones Técnicas Conocidas
- **Funciones duplicadas en BD:** El instalador generó múltiples overloads de las funciones PostgreSQL. No eliminar las viejas porque pueden romperse otras cosas. La solución es el cast explícito en PHP.
- **Control de Estado de Formularios:** Acordamos que siempre habrá que manejar y borrar la retención forzada del navegador en entradas tipo `<input type="file">`.
- **DB Connection:** DB se llama `db_rdwatch`. Verificar siempre `src/backend/.env` si hay errores de conexión.

## ⏳ 5. Tareas Pendientes y Completadas (Snapshot)
- [x] Corregir instalador `.bat` y `.env` para sincronismo local.
- [x] Reparar header fantasma por defecto en facturación (`.header--solid`).
- [x] Corregir retención de variables DOM estáticas en checkout (Bfcache).
- [x] Fix ciudades no cargan (`fn_geo_ciudades` ambigua → `?::INTEGER` en PHP).
- [x] Fix no se pueden crear reseñas (`fn_reviews_create` ambigua → `?::INTEGER` en PHP).
- [x] Fix checkout falla (`fn_checkout_process` ambigua → `?::INTEGER` en PHP).
- [x] Fix encoding UTF-8 doble en respuestas JSON (DSN PDO con `--client-encoding=UTF8`).
- [x] Fix carrito falla al agregar producto (`fn_cart_get_or_create` ambigua → `::INTEGER` en PHP + casts en toda la API).
- [x] **Limpieza definitiva BD**: Se eliminaron los 70 overloads obsoletos de 46 funciones ejecutando `sql/cleanup_overloads.sql`. La BD pasó de 143 a 73 funciones. Ya NO hay ambigüedad en ninguna función.
- [x] Fix eliminar productos/marcas/categorías/servicios del admin: los deletes pasaban 2 params (ID + user_id) pero las funciones en BD quedaron con 1 param. Corregido en `marcas.php`, `categorias.php`, `productos.php`, `servicios.php`. También se fijó `validateCsrfToken()` → `validateCsrfToken(null, true)` en DELETE de categorías/subcategorías. Cast `::BIGINT` en servicios porque su firma es `bigint`.
- [x] **Fix visual soft-delete**: El trigger de PostgreSQL se arregló para que ahora SÍ cambie el `estado = false` (antes se mantenía en `true` y causaba que el admin lo siguiera viendo como activo a pesar de borrarlo). Se mantiene el diseño visual donde el registro borrado se oscurece y cambia su botón a "Reactivar".
- [x] **Consolidación para Producción**: El código del nuevo trigger solucionado (`fun_audit_rdwatch` con manejo dinámico del campo estado) se consolidó definitivamente en `sql/triggers/audit_trail.sql`. Se eliminaron todos los scripts "parche" temporales (`fix_audit_trigger.sql`, `fix_estado_huerfanos.sql`, `cleanup_overloads.sql`, `test_trigger.sql`) dejando el repositorio limpio. Al ejecutar `install_db.bat` en un entorno de producción o limpio, la base de datos se instalará directamente sin overloads y con el trigger de soft-delete funcionando correctamente.
- [x] **Fix subcategorías admin panel**: Las subcategorías no se eliminaban porque PHP pasaba 2 params a `fn_cat_delete_subcategoria` que requería 3 (faltaba `p_usr`). Además se cambió el comportamiento completo: ya NO se eliminan, se **desactivan/reactivan** con el mismo patrón de soft-delete que marcas, categorías, productos y servicios. Se agregó parámetro `p_estado` a `fn_cat_update_subcategoria` para soportar reactivación vía PUT. Se limpió el overload viejo de 3 params (sin estado) y se creó `fn_cat_delete_subcategoria(integer, integer, varchar)` en la BD activa.
- [x] **Fix encoding tildes en BD (12/04/2026):** Los archivos `.sql` de seeds estaban en UTF-8 pero `psql` en Windows los leía como WIN1252/Latin-1, causando doble-codificación (`Ã³`→`ó`, `Ã¡`→`á`). Se corrigieron los datos ya existentes con `convert_from(convert_to(input, 'LATIN1'), 'UTF8')` afectando: 10 servicios, 15 productos, 2 categorías, 3 subcategorías, 3 reseñas, 12 departamentos y 72 ciudades. Se agregó `PGCLIENTENCODING=UTF8` a `install_db.bat` y `install_db.sh` para que futuras instalaciones no corrompan datos.
- [x] Probar flujo completo en el navegador (carrito → checkout → reseña → servicio → ciudades → eliminar items desde admin).
- [x] **Optimización Masiva de APIs (24/04/2026):** Refactorización de 14 archivos PHP para eliminar el overhead de procesamiento JSON y estandarizar códigos de error HTTP.
- [x] **Fix Tabla Servicios Admin (24/04/2026):** Corregido descuadre visual en el panel administrativo al añadir la columna "Estado" faltante en el header de servicios.
- [x] **Fix Soft-Delete Marcas/Servicios (24/04/2026):** Se corrigió el error de parámetros faltantes en las llamadas PHP a `fn_cat_delete_marca` y `fn_cat_delete_servicio`.
- [x] **UI Productos Agotados (24/04/2026):** Implementación de feedback visual en el comercio para productos sin stock: etiqueta "Agotado", opacidad/escala de grises, y bloqueo de botones de compra.
- [x] **UI Factura (24/04/2026):** Conversión del botón de contacto urgente en la factura a un elemento gráfico estático (span no interactivo).

- [x] **Refactorización `%TYPE` (23/04/2026):** Se aplicó el atributo `%TYPE` a más de 60 funciones PL/pgSQL en los 5 módulos principales (`admin_reports.sql`, `auth_security.sql`, `catalog_master.sql`, `client_panel.sql`, `ecommerce_core.sql`) asegurando resiliencia ante cambios de esquema futuros.

- [x] **Rate Limits de Citas (28/04/2026):** Implementado control completo de frecuencia y horario en `fn_citas_create` (7 validaciones) y cancelación anticipada en `fn_citas_update_status`. Validación duplicada en `citas.php` (PHP). Frontend actualizado con banner informativo y selector de fecha con mínimo +2 días. **Consolidación:** Las funciones actualizadas se integraron definitivamente en `sql/logica_backend/ecommerce_core.sql` para nuevas instalaciones. El script `sql/scripts/migrate_citas_limits.sql` quedó como utilidad de parcheo.

---
*Última edición técnica: Lunes 28 Abril 2026 — Rate Limits y Horario de Atención para Citas/Servicios*
