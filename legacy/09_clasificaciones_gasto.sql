-- =====================================================================
-- MIGRACIÓN: Tabla de clasificaciones de gastos (maestro, como categorías)
-- =====================================================================

CREATE TABLE IF NOT EXISTS gastos.clasificaciones (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(50) NOT NULL UNIQUE,
    created_at  TIMESTAMP DEFAULT now()
);

INSERT INTO gastos.clasificaciones (nombre) VALUES
    ('Suministros'),
    ('Operacional'),
    ('Administrativo')
ON CONFLICT (nombre) DO NOTHING;

ALTER TABLE gastos.gastos DROP CONSTRAINT IF EXISTS gastos_clasificacion_check;
ALTER TABLE gastos.gastos DROP CONSTRAINT IF EXISTS gastos_gastos_clasificacion_check;

ALTER TABLE gastos.gastos
    ADD CONSTRAINT fk_gasto_clasificacion
    FOREIGN KEY (clasificacion)
    REFERENCES gastos.clasificaciones(nombre);
