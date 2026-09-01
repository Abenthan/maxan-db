ALTER TABLE helpdesk.caso_detalles ADD COLUMN recurso_id INTEGER REFERENCES helpdesk.recursos(id) ON DELETE SET NULL;

ALTER TABLE helpdesk.caso_detalles DROP CONSTRAINT IF EXISTS caso_detalles_tipo_check;
ALTER TABLE helpdesk.caso_detalles ADD CONSTRAINT caso_detalles_tipo_check
  CHECK (tipo IN ('Comentario', 'Diagnóstico', 'Solución', 'Acuerdo', 'Sistema', 'Novedad', 'Observaciones'));
