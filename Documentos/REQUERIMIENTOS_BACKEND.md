# REQUERIMIENTOS DEL BACKEND — RD_WATCH

Este documento contiene el listado maestro de requerimientos funcionales y no funcionales de la arquitectura de backend del software, organizados por módulos y utilizando el estándar de nomenclatura (`RFxxx` para funcionales, `RNFxxx` para no funcionales).

---

## 🟢 REQUERIMIENTOS FUNCIONALES

### 1. AUTENTICACIÓN Y GESTIÓN DE SESIÓN
| Nº | REQUERIMIENTO | SI | NO | ADI | OBSERVACIONES |
|:---:|---|:---:|:---:|:---:|---|
| RF001 | El sistema debe permitir el inicio de sesión a usuarios registrados (clientes y administradores) requiriendo email y contraseña. | x | | | |
| RF002 | El sistema debe bloquear el acceso a la cuenta tras 5 intentos fallidos consecutivos de inicio de sesión durante 15 minutos (rate limiting/lockout). | x | | | |
| RF003 | El sistema debe permitir al usuario restablecer su contraseña de forma segura mediante un enlace de recuperación con token único enviado a su correo electrónico. | x | | | |
| RF004 | El enlace de recuperación de contraseña debe expirar automáticamente a los 30 minutos de haber sido generado. | x | | | |
| RF005 | El sistema debe permitir cerrar la sesión activa, destruyendo todos los datos de sesión en el servidor y expirando las cookies correspondientes en el navegador del cliente. | x | | | |
| RF006 | El sistema debe implementar un flujo de autorización Oauth2 completo para permitir el inicio de sesión rápido mediante cuentas de Google (Sign in con Google). | x | | | |
| RF007 | Al registrarse un nuevo cliente mediante Google, el sistema debe autocompletar su perfil básico (nombre, email, avatar) y generar una cuenta local asociada sin requerir contraseña inicial. | x | | | |

### 2. CATÁLOGO Y CONTROL DE INVENTARIO
| Nº | REQUERIMIENTO | SI | NO | ADI | OBSERVACIONES |
|:---:|---|:---:|:---:|:---:|---|
| RF008 | El sistema debe consultar en tiempo real la base de datos para mostrar el catálogo estructurado de productos, marcas, categorías y servicios. | x | | | |
| RF009 | El sistema debe calcular y exponer visualmente la disponibilidad de stock de los productos, bloqueando compras de items "Agotados". | x | | | |
| RF010 | El sistema debe ocultar automáticamente del catálogo público aquellos elementos que el administrador elimine (borrado lógico), conservando su integridad histórica para pedidos pasados. | x | | | Soft-delete |

### 3. CARRITO DE COMPRAS Y PEDIDOS
| Nº | REQUERIMIENTO | SI | NO | ADI | OBSERVACIONES |
|:---:|---|:---:|:---:|:---:|---|
| RF011 | El sistema debe mantener de forma persistente el carrito de compras de un cliente permitiendo agregar, editar cantidades o quitar productos. | x | | | |
| RF012 | Al ejecutar el proceso de pago (checkout), el sistema debe totalizar costos y verificar la disponibilidad de unidades antes de consolidar el pedido. | x | | | |
| RF013 | Tras crear exitosamente un pedido, el sistema debe descontar automáticamente las unidades procesadas del inventario global de la tienda. | x | | | |
| RF014 | El sistema debe generar una factura digital oficial inalterable asociada de forma única al pedido del cliente. | x | | | |

### 4. TALLER Y AGENDAMIENTO DE CITAS
| Nº | REQUERIMIENTO | SI | NO | ADI | OBSERVACIONES |
|:---:|---|:---:|:---:|:---:|---|
| RF015 | El sistema debe permitir a los clientes enviar solicitudes para reservar citas de mantenimiento a cualquier hora del día (24/7). | x | | | |
| RF016 | El sistema debe restringir a los clientes la creación de reservas a un máximo de 1 solicitud por día y 2 solicitudes por semana. | x | | | Rate limits |
| RF017 | El sistema debe limitar la carga operativa del taller a un máximo de 10 citas por cada fecha de calendario específica. | x | | | Capacidad global |
| RF018 | El sistema debe impedir la selección de días domingo y exigir al cliente un mínimo de 2 días de anticipación para la fecha preferida. | x | | | |
| RF019 | El sistema debe permitir la cancelación de citas a clientes con mínimo 1 día de anticipación. Los administradores pueden cancelar sin restricciones de tiempo. | x | | | |

### 5. GESTIÓN ADMINISTRATIVA E INTERACCIONES
| Nº | REQUERIMIENTO | SI | NO | ADI | OBSERVACIONES |
|:---:|---|:---:|:---:|:---:|---|
| RF020 | El sistema debe proveer un panel exclusivo donde los administradores puedan crear, actualizar o dar de baja productos, categorías y servicios. | x | | | |
| RF021 | El sistema debe proveer tableros y reportes para listar facturas, usuarios registrados y citas generadas en el sistema. | x | | | |
| RF022 | El sistema debe permitir recibir, almacenar de forma segura y validar reseñas redactadas por clientes reales que hayan realizado compras previas. | x | | | |

<br><br>

---

## 🔵 REQUERIMIENTOS NO FUNCIONALES

### 1. AUTENTICACIÓN Y GESTIÓN DE SESIÓN
| Nº | REQUERIMIENTO | SI | NO | ADI | OBSERVACIONES |
|:---:|---|:---:|:---:|:---:|---|
| RNF001 | Toda comunicación entre el cliente y el servidor debe estar cifrada mediante TLS 1.2 o superior. No se permiten conexiones sin cifrar en producción (HTTP plano). | x | | | |
| RNF002 | Las contraseñas deben almacenarse siempre en formato hash usando bcrypt con factor de costo mínimo de 10. Nunca se almacenan en texto plano. El sistema debe soportar migración automática de hashes MD5+salt heredados a bcrypt en el próximo inicio de sesión del usuario. | x | | | |
| RNF003 | El sistema debe implementar autenticación basada en sesiones PHP (`$_SESSION`) con regeneración de ID de sesión inmediatamente después de cada inicio de sesión exitoso, para prevenir ataques de fijación de sesión. | x | | | |
| RNF004 | Las cookies de sesión deben configurarse con los flags Secure (solo HTTPS) y HttpOnly (no accesibles por JavaScript) en producción. | x | | | |
| RNF005 | Las sesiones deben tener un tiempo de expiración configurable (actualmente 7 días). Las sesiones expiradas o destruidas no deben otorgar acceso a ningún recurso. | x | | | |
| RNF006 | El sistema debe implementar autorización basada en roles (RBAC): cada operación debe verificar que el rol del usuario sea el autorizado para ejecutarla. Los endpoints administrativos rechazan con HTTP 403 (o 401) cualquier acceso sin el rol 'admin'. | x | | | |
| RNF007 | Todos los inputs del usuario deben validarse y sanitizarse en el servidor antes de ser procesados (trim, htmlspecialchars, strip_tags, validaciones de tipo y rango). La capa de presentación no es suficiente. | x | | | |
| RNF008 | Todas las consultas a la base de datos deben usar prepared statements (PDO con parámetros) para prevenir inyección SQL. Está prohibido construir consultas SQL concatenando variables de usuario. | x | | | |

### 2. CONFIABILIDAD E INTEGRIDAD DE DATOS
| Nº | REQUERIMIENTO | SI | NO | ADI | OBSERVACIONES |
|:---:|---|:---:|:---:|:---:|---|
| RNF009 | Los flujos críticos de la base de datos (ej. creación de pedido y rebaja de stock) deben operar bajo transacciones ACID, asegurando completitud o reversión total (Rollback) ante fallos. | x | | | Todo o nada |
| RNF010 | El backend (API PHP) debe forzar explícitamente el parámetro `client_encoding=UTF8` al conectarse a PostgreSQL para prevenir corrupción en caracteres de doble byte. | x | | | Solución a tildes |
| RNF011 | El control de eventos de la base de datos debe ser manejado mediante Triggers internos (ej. `audit_trail.sql`) que auto-inscriban el usuario actuante y estampa de tiempo tras cada `INSERT` o `UPDATE`. | x | | | Trazabilidad |
| RNF012 | La eliminación de registros críticos desde el panel administrador debe interceptarse a través de un Trigger que transforme el comando en una actualización de desactivación (borrado lógico). | x | | | `estado = false` |

### 3. MANTENIBILIDAD, RENDIMIENTO Y ESCALABILIDAD
| Nº | REQUERIMIENTO | SI | NO | ADI | OBSERVACIONES |
|:---:|---|:---:|:---:|:---:|---|
| RNF013 | Las funciones PL/pgSQL deben declarar los tipos de datos de sus parámetros y variables apoyándose en la directiva `%TYPE` (ej. `p_id tab_Usuarios.id_usuario%TYPE`), asegurando resiliencia ante rediseños de esquema. | x | | | Estabilidad |
| RNF014 | Las API de PHP no deben realizar doble decodificación/codificación JSON. Deben retornar al frontend la respuesta JSON exacta impresa por las funciones de PostgreSQL para reducir carga de RAM y CPU. | x | | | Optimización de servidor |
| RNF015 | Toda la lógica de negocio autoritativa (límites de citas, suma de carritos) debe residir como Procedimiento Almacenado dentro del motor SQL para maximizar el rendimiento. | x | | | Capa autoritativa |
| RNF016 | Las API de respuesta del servidor deben acatar la semántica RESTful emitiendo códigos HTTP de respuesta estrictos (`200 OK`, `400 Bad Request`, `403 Forbidden`, `500 Internal Error`). | x | | | |
| RNF017 | Todas las operaciones, tanto en la capa SQL como en la capa PHP, deben forzar explícitamente la ejecución bajo la zona horaria `America/Bogota` para asegurar coherencia transaccional. | x | | | Evita desfase temporal |
