-- =====================================================================
-- MIGRACIÓN: Agregar código único a productos
-- =====================================================================

ALTER TABLE inventario.productos ADD COLUMN codigo VARCHAR(50);

UPDATE inventario.productos SET codigo = 'PROD-' || LPAD(id::text, 4, '0') WHERE codigo IS NULL;

ALTER TABLE inventario.productos ALTER COLUMN codigo SET NOT NULL;
ALTER TABLE inventario.productos ADD CONSTRAINT uq_productos_codigo UNIQUE (codigo);
