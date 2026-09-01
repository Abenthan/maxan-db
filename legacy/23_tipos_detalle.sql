CREATE TABLE IF NOT EXISTS helpdesk.tipos_detalle (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(50) NOT NULL UNIQUE,
  color VARCHAR(7) NOT NULL DEFAULT '#92400e',
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO helpdesk.tipos_detalle (nombre, color) VALUES
  ('Comentario', '#92400e'),
  ('Diagnóstico', '#7c3aed'),
  ('Solución', '#166534'),
  ('Acuerdo', '#1e40af'),
  ('Sistema', '#6b7280'),
  ('Novedad', '#ea580c'),
  ('Observaciones', '#0d9488')
ON CONFLICT (nombre) DO NOTHING;

ALTER TABLE helpdesk.caso_detalles DROP CONSTRAINT IF EXISTS caso_detalles_tipo_check;
ALTER TABLE helpdesk.caso_detalles ADD CONSTRAINT caso_detalles_tipo_fk FOREIGN KEY (tipo) REFERENCES helpdesk.tipos_detalle(nombre);
