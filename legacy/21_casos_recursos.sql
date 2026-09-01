-- Migration 21: Many-to-many entre casos y recursos
-- Permite vincular uno o varios recursos a un caso de soporte

CREATE TABLE IF NOT EXISTS helpdesk.casos_recursos (
  caso_id INTEGER NOT NULL REFERENCES helpdesk.casos(id) ON DELETE CASCADE,
  recurso_id INTEGER NOT NULL REFERENCES helpdesk.recursos(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (caso_id, recurso_id)
);

-- Migrar recurso_id existente de helpdesk.casos a la nueva tabla pivote
INSERT INTO helpdesk.casos_recursos (caso_id, recurso_id)
SELECT id, recurso_id FROM helpdesk.casos WHERE recurso_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- Nota: la columna recurso_id en helpdesk.casos se mantiene por compatibilidad
-- pero ya no se usa para nuevos registros. En el futuro se puede eliminar.
