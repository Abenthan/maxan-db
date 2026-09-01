-- Tabla maestra de tipos de recurso
CREATE TABLE IF NOT EXISTS helpdesk.tipos_recurso (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(50) NOT NULL UNIQUE,
    created_at  TIMESTAMP DEFAULT now()
);

INSERT INTO helpdesk.tipos_recurso (nombre) VALUES
    ('Computador'),
    ('Hosting'),
    ('Office 365'),
    ('Red'),
    ('Celular'),
    ('Impresora'),
    ('Servidor'),
    ('UPS'),
    ('Cámara'),
    ('Otro')
ON CONFLICT (nombre) DO NOTHING;

-- Migrar constraint CHECK a FK
ALTER TABLE helpdesk.recursos DROP CONSTRAINT IF EXISTS helpdesk_recursos_tipo_check;
ALTER TABLE helpdesk.recursos DROP CONSTRAINT IF EXISTS recursos_tipo_check;
ALTER TABLE helpdesk.recursos DROP CONSTRAINT IF EXISTS fk_recurso_tipo;

ALTER TABLE helpdesk.recursos
    ADD CONSTRAINT fk_recurso_tipo
    FOREIGN KEY (tipo)
    REFERENCES helpdesk.tipos_recurso(nombre)
    ON DELETE RESTRICT;
