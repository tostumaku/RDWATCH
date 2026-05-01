# Requerimientos de la Sección de Servicios (Actualización Panel de Usuario)

A continuación se detallan los requerimientos funcionales y no funcionales que fueron implementados durante la sesión de hoy, basándonos estrictamente en el formato de matriz de validación que solicitaste.

### REQUERIMIENTOS FUNCIONALES — 4. SECCIÓN DE SERVICIOS (ACTUALIZACIÓN LÍMITES)

| Nº | REQUERIMIENTO | SI | NO | ADI | OBSERVACIONES |
|:---:|---|:---:|:---:|:---:|---|
| 1 | La sección de servicios muestra un banner informativo destacado detallando el horario de atención del taller. | x | | | |
| 2 | El banner detalla que el horario es de Lunes a Viernes (10:00 AM - 6:00 PM) y Sábados (10:00 AM - 3:00 PM). | x | | | |
| 3 | El banner indica explícitamente que los domingos no hay disponibilidad de atención. | x | | | |
| 4 | El banner informa a los usuarios que pueden enviar solicitudes de citas en cualquier momento (24/7). | x | | | |
| 5 | El banner comunica de forma clara el límite de 1 solicitud máxima por día por cliente. | x | | | |
| 6 | El banner comunica de forma clara el límite de 2 solicitudes máximas por semana por cliente. | x | | | |
| 7 | El banner especifica que se requieren mínimo 2 días de anticipación para la fecha de la cita preferida. | x | | | |
| 8 | Las tarjetas de servicio permanecen habilitadas y el botón «Solicitar» es cliqueable las 24 horas del día. | x | | | Modificado tras corrección de UX |
| 9 | El sistema bloquea la selección de días domingo al momento de elegir la fecha en el formulario de la cita. | x | | | |
| 10 | El sistema bloquea la selección de fechas que no cumplan con el mínimo de 2 días de anticipación. | x | | | |
| 11 | El sistema rechaza la creación de una cita si el usuario ya posee una solicitud activa para ese mismo servicio en la fecha indicada (anti-duplicado). | x | | | |
| 12 | El sistema valida y bloquea la solicitud si el cliente intenta agendar más de 1 cita creada en el transcurso del día actual. | x | | | |
| 13 | El sistema valida y bloquea la solicitud si el cliente intenta agendar más de 2 citas creadas durante la semana actual. | x | | | |
| 14 | El sistema valida y bloquea la solicitud si la fecha seleccionada ya alcanzó la capacidad operativa global (10 citas agendadas para ese día). | x | | | |
| 15 | El cliente tiene permitido cancelar una cita previamente agendada únicamente si lo hace con al menos 1 día de anticipación a la fecha programada. | x | | | |

<br>

### REQUERIMIENTOS NO FUNCIONALES — 4. SECCIÓN DE SERVICIOS (ACTUALIZACIÓN LÍMITES)

| Nº | REQUERIMIENTO | SI | NO | ADI | OBSERVACIONES |
|:---:|---|:---:|:---:|:---:|---|
| 1 | La validación de fechas (anticipación mínima y bloqueo de domingos) debe ejecutarse de manera anticipada en la capa API (PHP) antes de realizar peticiones a la BD. | x | | | Ahorro de recursos del servidor |
| 2 | Las validaciones de los límites de cuota (diaria, semanal, global) deben resolverse centralizadamente en PostgreSQL para garantizar consistencia ACID. | x | | | Lógica autoritativa |
| 3 | Las consultas de conteo en la base de datos deben utilizar la función `COUNT(1)` en lugar de `COUNT(*)` por estándar de optimización del proyecto. | x | | | |
| 4 | El sistema debe forzar explícitamente la variable de entorno de zona horaria a `America/Bogota` tanto en la ejecución de la función SQL como en el script PHP. | x | | | Previene desincronización horaria |
| 5 | El banner informativo debe estructurarse en HTML dentro de un contenedor propio identificado con la clase `.services-info-banner`. | x | | | |
| 6 | El icono decorativo principal del banner debe hacer uso de la clase `.info-banner-icon` y renderizar un icono representativo de FontAwesome (`fa-info-circle`). | x | | | |
| 7 | Los elementos informativos dentro del banner deben listarse y ser acompañados de los iconos `fa-calendar-week`, `fa-calendar-day` y `fa-ban`. | x | | | |
| 8 | Las reglas de límites deben agruparse en un párrafo independiente con la clase `.info-banner-limits` y ser encabezados por un icono de escudo (`fa-shield-alt`). | x | | | |
| 9 | El mapeo de variables que interactúan con IDs en PostgreSQL debe respetar la correspondencia de tipos, obligando al casteo estricto a `SMALLINT` (`?::SMALLINT`) desde PHP. | x | | | Previene error 500 por mismatch |
| 10 | Las citas que se encuentren bajo el estado `cancelada` no deben ser consideradas en el conteo de registros al validar los límites de cliente ni los globales. | x | | | |
| 11 | El sistema debe incluir una excepción en la capa SQL para que los administradores puedan eludir la restricción de cancelación anticipada (identificados por el prefijo `admin_`). | x | | | |
| 12 | Las peticiones a la API que no cumplan con las reglas de negocio deben retornar códigos de estado HTTP semánticos (`400 Bad Request` o `403 Forbidden`). | x | | | |
