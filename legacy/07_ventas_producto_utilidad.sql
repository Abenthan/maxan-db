-- =====================================================================
-- MIGRACIÓN: producto_id en ventas_items + vw_utilidad_productos
-- =====================================================================

ALTER TABLE facturacion.ventas_items
ADD COLUMN producto_id INT REFERENCES inventario.productos(id);

CREATE OR REPLACE VIEW inventario.vw_utilidad_productos AS
SELECT
    p.id AS producto_id,
    p.codigo,
    p.nombre,
    p.categoria,
    COALESCE(compras.costo_adquisiciones, 0) AS costo_adquisiciones,
    COALESCE(ventas.ingreso_ventas, 0) AS ingreso_ventas,
    COALESCE(gastos_extra.otros_costos, 0) AS otros_costos,
    COALESCE(ventas.ingreso_ventas, 0) - COALESCE(compras.costo_adquisiciones, 0) - COALESCE(gastos_extra.otros_costos, 0) AS utilidad
FROM inventario.productos p
LEFT JOIN (
    SELECT e.producto_id, SUM(e.cantidad * e.costo_unitario) AS costo_adquisiciones
    FROM inventario.entradas e
    GROUP BY e.producto_id
) compras ON compras.producto_id = p.id
LEFT JOIN (
    SELECT s.producto_id, SUM(vi.valor_linea) AS ingreso_ventas
    FROM inventario.salidas s
    JOIN facturacion.ventas_items vi ON vi.id = s.factura_item_id
    GROUP BY s.producto_id
) ventas ON ventas.producto_id = p.id
LEFT JOIN (
    SELECT g.producto_id, SUM(g.valor_total) AS otros_costos
    FROM gastos.gastos g
    WHERE g.producto_id IS NOT NULL AND g.venta_item_id IS NULL AND g.clasificacion <> 'Suministros'
    GROUP BY g.producto_id
) gastos_extra ON gastos_extra.producto_id = p.id
ORDER BY p.nombre;
