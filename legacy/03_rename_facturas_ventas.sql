-- =====================================================================
-- RENOMBRAR: facturas → ventas, factura_items → ventas_items
-- =====================================================================

DROP VIEW IF EXISTS facturacion.vw_facturas_resumen;
DROP VIEW IF EXISTS facturacion.vw_utilidad_items;

ALTER TABLE facturacion.facturas RENAME TO ventas;
ALTER SEQUENCE facturacion.facturas_id_seq RENAME TO ventas_id_seq;

ALTER TABLE facturacion.factura_items RENAME TO ventas_items;
ALTER SEQUENCE facturacion.factura_items_id_seq RENAME TO ventas_items_id_seq;

ALTER TABLE facturacion.ventas_items RENAME COLUMN factura_id TO venta_id;

CREATE OR REPLACE VIEW facturacion.vw_facturas_resumen AS
SELECT
    v.id,
    v.numero_completo,
    v.cufe,
    v.fecha_emision,
    v.fecha_vencimiento,
    e.razon_social AS emisor,
    e.numero_documento AS nit_emisor,
    r.razon_social AS receptor,
    r.numero_documento AS nit_receptor,
    v.valor_a_pagar,
    v.estado,
    v.codigo_respuesta_dian,
    v.estado_validacion_dian
FROM facturacion.ventas v
JOIN generales.terceros e ON e.id = v.emisor_id
JOIN generales.terceros r ON r.id = v.receptor_id;

CREATE OR REPLACE VIEW facturacion.vw_utilidad_items AS
SELECT
    fi.id AS factura_item_id,
    fi.descripcion,
    fi.valor_linea,
    COALESCE(sal.costo_inventario, 0) AS costo_inventario,
    COALESCE(gd.costo_directo, 0)     AS costo_directo,
    fi.valor_linea - COALESCE(sal.costo_inventario, 0) - COALESCE(gd.costo_directo, 0) AS utilidad
FROM facturacion.ventas_items fi
LEFT JOIN (
    SELECT factura_item_id, SUM(costo_total) AS costo_inventario
    FROM inventario.salidas GROUP BY factura_item_id
) sal ON sal.factura_item_id = fi.id
LEFT JOIN (
    SELECT venta_item_id, SUM(valor_total) AS costo_directo
    FROM gastos.gastos WHERE venta_item_id IS NOT NULL GROUP BY venta_item_id
) gd ON gd.venta_item_id = fi.id;
