-- ============================================================
-- maxan-db — seeds/05_helpdesk.sql
-- Catálogos maestros del módulo helpdesk (datos maestros).
--   helpdesk.tipos_recurso
--   helpdesk.tipos_detalle
--   helpdesk.categorias_caso
--   helpdesk.categorias_mantenimiento
-- Idempotente: se puede ejecutar varias veces sin error.
-- Generado desde el dump real.
-- ============================================================

-- Tipos de recurso
INSERT INTO helpdesk.tipos_recurso (id, nombre)
VALUES
    (1,  'Computador'),
    (2,  'Hosting'),
    (3,  'Office 365'),
    (4,  'Red'),
    (5,  'Impresora'),
    (6,  'Otro'),
    (7,  'Servicios SaaS'),
    (8,  'Antivirus'),
    (9,  'Servidor de archivos')
ON CONFLICT (nombre) DO NOTHING;

-- Tipos de detalle (en casos/mantenimientos)
INSERT INTO helpdesk.tipos_detalle (id, nombre, color)
VALUES
    (1, 'Comentario',    '#92400e'),
    (2, 'Diagnóstico',   '#7c3aed'),
    (3, 'Solución',      '#166534'),
    (4, 'Novedad',       '#ea580c'),
    (5, 'Observaciones', '#0d9488'),
    (6, 'Acciones',      '#0361fc'),
    (7, 'Conclusión',    '#1a861f')
ON CONFLICT (nombre) DO NOTHING;

-- Categorías de caso
INSERT INTO helpdesk.categorias_caso (id, nombre, color)
VALUES
    (1, 'Falla / Error',       '#EF4444'),
    (2, 'Instalación',         '#10B981'),
    (3, 'Mantenimiento',       '#8B5CF6'),
    (4, 'Configuración',       '#14B8A6'),
    (5, 'Software',            '#11357e'),
    (6, 'Gestion de Correos',  '#ff8000'),
    (7, 'Antivirus',           '#0d8c1c'),
    (8, 'Copia de seguridad',  '#6B7280')
ON CONFLICT (nombre) DO NOTHING;

-- Categorías de mantenimiento
INSERT INTO helpdesk.categorias_mantenimiento (id, nombre, color)
VALUES
    (1, 'Mantenimiento Preventivo',    '#10B981'),
    (2, 'Mantenimiento Correctivo',    '#EF4444'),
    (3, 'Instalación / Configuración', '#3B82F6'),
    (4, 'Diagnóstico',                 '#F59E0B'),
    (5, 'Soporte Remoto',              '#8B5CF6'),
    (6, 'Formateo / Backup',           '#EC4899'),
    (7, 'Redes / Cableado',            '#14B8A6')
ON CONFLICT (nombre) DO NOTHING;