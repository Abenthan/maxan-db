ALTER TABLE generales.terceros ALTER COLUMN tipo_documento DROP NOT NULL;
ALTER TABLE generales.terceros ALTER COLUMN numero_documento DROP NOT NULL;

ALTER TABLE generales.terceros DROP CONSTRAINT IF EXISTS terceros_tipo_documento_numero_documento_key;

ALTER TABLE generales.terceros
  ADD CONSTRAINT terceros_documento_unique UNIQUE (tipo_documento, numero_documento);

DROP INDEX IF EXISTS generales.terceros_tipo_documento_numero_documento_idx;
