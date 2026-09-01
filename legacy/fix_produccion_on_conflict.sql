-- ================================================================
-- Fix: reemplazar índice parcial por UNIQUE constraint completo
-- Ejecutar en DBeaver contra la BD de producción
-- 
-- El índice parcial (WHERE ... IS NOT NULL) no es compatible
-- con ON CONFLICT (columns). PostgreSQL no puede usarlo como
-- conflict target.
--
-- Un UNIQUE constraint completo sobre columnas nullable SÍ permite
-- múltiples NULLs (estándar SQL: NULL != NULL).
-- ================================================================

BEGIN;

DROP INDEX IF EXISTS generales.terceros_tipo_documento_numero_documento_idx;

ALTER TABLE generales.terceros
  ADD CONSTRAINT terceros_documento_unique UNIQUE (tipo_documento, numero_documento);

COMMIT;

-- ================================================================
-- Verificación post-ejecución:
--   SELECT * FROM pg_indexes WHERE tablename = 'terceros';
-- Debe mostrar "terceros_documento_unique" sin WHERE clause.
-- ================================================================
