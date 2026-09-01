-- Agrega columna JSONB para atributos variables por tipo de recurso
ALTER TABLE helpdesk.recursos ADD COLUMN IF NOT EXISTS atributos JSONB DEFAULT '{}';
