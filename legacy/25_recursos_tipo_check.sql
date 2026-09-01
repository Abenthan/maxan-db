-- Fix: la migración 20_tipos_recurso intentaba eliminar el constraint CHECK
-- con el nombre "helpdesk_recursos_tipo_check", pero PostgreSQL auto-nombra
-- los constraints de la tabla helpdesk.recursos como "recursos_tipo_check".
-- Por eso el CHECK seguía vigente en producción y rechazaba tipos nuevos
-- (ej: "Servidor de archivos") a pesar de existir la tabla maestra tipos_recurso.

-- Eliminar el CHECK residual (por ambos nombres posibles)
ALTER TABLE helpdesk.recursos DROP CONSTRAINT IF EXISTS helpdesk_recursos_tipo_check;
ALTER TABLE helpdesk.recursos DROP CONSTRAINT IF EXISTS recursos_tipo_check;

-- Recrear el FK por si acaso no existiera
ALTER TABLE helpdesk.recursos DROP CONSTRAINT IF EXISTS fk_recurso_tipo;
ALTER TABLE helpdesk.recursos
    ADD CONSTRAINT fk_recurso_tipo
    FOREIGN KEY (tipo)
    REFERENCES helpdesk.tipos_recurso(nombre)
    ON DELETE RESTRICT;
