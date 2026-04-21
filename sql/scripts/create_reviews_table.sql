-- =====================================================
-- Tabla: tab_Opiniones
-- Almacena las reseñas y calificaciones de los usuarios.
-- =====================================================

CREATE TABLE IF NOT EXISTS tab_Opiniones
(
    id_opinion      SERIAL PRIMARY KEY,           -- Identificador único de la reseña
    id_usuario      BIGINT NOT NULL,              -- Usuario que realiza la reseña
    calificacion    SMALLINT NOT NULL CHECK (calificacion >= 1 AND calificacion <= 5), -- Puntuación (1-5)
    comentario      TEXT NOT NULL,                -- Texto de la reseña
    fecha_opinion   TIMESTAMP DEFAULT CURRENT_TIMESTAMP, -- Fecha de publicación
    activo          BOOLEAN DEFAULT TRUE,         -- Estado de la reseña
    
    -- Auditoría
    usr_insert      VARCHAR(100),
    fec_insert      TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
    usr_update      VARCHAR(100),
    fec_update      TIMESTAMP,

    -- Llave foránea
    CONSTRAINT fk_opinion_usuario FOREIGN KEY (id_usuario) REFERENCES tab_Usuarios (id_usuario) ON DELETE CASCADE
);

-- Índices para mejorar el rendimiento
CREATE INDEX IF NOT EXISTS idx_opiniones_usuario ON tab_Opiniones (id_usuario);
CREATE INDEX IF NOT EXISTS idx_opiniones_fecha   ON tab_Opiniones (fecha_opinion DESC);
CREATE INDEX IF NOT EXISTS idx_opiniones_activo  ON tab_Opiniones (activo);
