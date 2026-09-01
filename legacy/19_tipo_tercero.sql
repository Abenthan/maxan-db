ALTER TABLE generales.terceros ADD COLUMN es_cliente BOOLEAN DEFAULT FALSE;
ALTER TABLE generales.terceros ADD COLUMN es_proveedor BOOLEAN DEFAULT FALSE;

-- Backfill: terceros que aparecen como receptor en ventas son clientes
UPDATE generales.terceros SET es_cliente = TRUE
WHERE id IN (SELECT DISTINCT receptor_id FROM facturacion.ventas);

-- Backfill: terceros que aparecen como emisor/proveedor en ventas/compras son proveedores
UPDATE generales.terceros SET es_proveedor = TRUE
WHERE id IN (SELECT DISTINCT emisor_id FROM facturacion.ventas)
   OR id IN (SELECT DISTINCT proveedor_id FROM compras.facturas_compra);
