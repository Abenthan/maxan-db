-- ============================================================
-- FIX PRODUCCIÓN: secuencia + vistas faltantes
-- Ejecutar en DBeaver o psql contra la BD de producción
-- ============================================================

BEGIN;

-- 1. Reparar secuencia de generales.terceros
--    (DROP CASCADE de facturacion.terceros eliminó la secuencia original)
CREATE SEQUENCE IF NOT EXISTS generales.terceros_id_seq;
ALTER TABLE generales.terceros ALTER COLUMN id SET DEFAULT nextval('generales.terceros_id_seq');
SELECT setval('generales.terceros_id_seq', COALESCE((SELECT MAX(id) FROM generales.terceros), 1));

-- 2. Crear/actualizar vistas del schema cartera
DROP VIEW IF EXISTS cartera.vw_cartera_activa;
CREATE OR REPLACE VIEW cartera.vw_cartera_activa AS
SELECT
    v.id AS venta_id,
    v.numero_completo,
    v.fecha_emision,
    v.fecha_vencimiento,
    v.fecha_vencimiento_pago,
    v.valor_a_pagar,
    v.valor_retencion_fuente,
    v.valor_a_pagar - COALESCE(v.saldo_pendiente, 0) AS total_pagado,
    COALESCE(v.saldo_pendiente, v.valor_a_pagar) AS saldo_pendiente,
    t.id AS cliente_id,
    t.razon_social AS cliente,
    t.numero_documento AS nit_cliente,
    v.estado,
    CASE
        WHEN COALESCE(v.saldo_pendiente, v.valor_a_pagar) <= 0 THEN 'Pagada'
        WHEN v.fecha_vencimiento_pago IS NULL THEN 'Sin vencimiento'
        WHEN CURRENT_DATE > v.fecha_vencimiento_pago THEN 'Vencida'
        ELSE 'Al día'
    END AS estado_cartera,
    CASE
        WHEN COALESCE(v.saldo_pendiente, v.valor_a_pagar) <= 0 THEN 0
        WHEN v.fecha_vencimiento_pago IS NULL THEN 0
        WHEN CURRENT_DATE <= v.fecha_vencimiento_pago THEN 0
        WHEN (CURRENT_DATE - v.fecha_vencimiento_pago) <= 30 THEN 30
        WHEN (CURRENT_DATE - v.fecha_vencimiento_pago) <= 60 THEN 60
        WHEN (CURRENT_DATE - v.fecha_vencimiento_pago) <= 90 THEN 90
        ELSE 999
    END AS dias_vencida
FROM facturacion.ventas v
JOIN generales.terceros t ON t.id = v.receptor_id
WHERE v.estado NOT IN ('anulada', 'rechazada')
ORDER BY v.fecha_vencimiento_pago NULLS LAST, v.fecha_emision DESC;

CREATE OR REPLACE VIEW cartera.vw_pagos_resumen AS
SELECT
    p.id,
    p.fecha_pago,
    p.valor_total,
    p.referencia,
    p.anulado,
    mp.nombre AS medio_pago,
    t.id AS cliente_id,
    t.razon_social AS cliente,
    t.numero_documento AS nit_cliente,
    COALESCE(pa.facturas_aplicadas, 0) AS facturas_aplicadas,
    COALESCE(pa.total_aplicado, 0) AS total_aplicado,
    CASE WHEN COALESCE(pa.total_aplicado, 0) < p.valor_total THEN p.valor_total - COALESCE(pa.total_aplicado, 0) ELSE 0 END AS sin_aplicar
FROM cartera.pagos p
JOIN generales.terceros t ON t.id = p.cliente_id
LEFT JOIN cartera.medios_pago mp ON mp.id = p.medio_pago_id
LEFT JOIN (
    SELECT pago_id, COUNT(*) AS facturas_aplicadas, SUM(valor_aplicado) AS total_aplicado
    FROM cartera.pago_aplicaciones
    GROUP BY pago_id
) pa ON pa.pago_id = p.id
ORDER BY p.fecha_pago DESC, p.id DESC;

CREATE OR REPLACE VIEW cartera.vw_pago_detalle AS
SELECT
    pa.id AS aplicacion_id,
    pa.pago_id,
    pa.venta_id,
    pa.valor_aplicado,
    pa.created_at AS fecha_aplicacion,
    v.numero_completo AS factura_numero,
    v.fecha_emision AS factura_fecha,
    v.valor_a_pagar AS factura_valor
FROM cartera.pago_aplicaciones pa
JOIN facturacion.ventas v ON v.id = pa.venta_id;

-- 3. Crear/actualizar vistas del schema facturacion
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
    v.estado_validacion_dian,
    v.observaciones
FROM facturacion.ventas v
JOIN generales.terceros e ON e.id = v.emisor_id
JOIN generales.terceros r ON r.id = v.receptor_id;

DROP VIEW IF EXISTS facturacion.vw_utilidad_items;
CREATE OR REPLACE VIEW facturacion.vw_utilidad_items AS
SELECT
    fi.id AS venta_item_id,
    fi.descripcion,
    fi.valor_linea,
    fi.producto_id,
    COALESCE(v.valor_retencion_fuente, 0) AS valor_retencion_fuente,
    COALESCE(sal.costo_inventario, 0) AS costo_inventario,
    COALESCE(gd.costo_directo, 0)     AS costo_directo,
    fi.valor_linea - COALESCE(sal.costo_inventario, 0) - COALESCE(gd.costo_directo, 0) - COALESCE(v.valor_retencion_fuente, 0) AS utilidad
FROM facturacion.ventas_items fi
JOIN facturacion.ventas v ON v.id = fi.venta_id
LEFT JOIN (
    SELECT factura_item_id, SUM(costo_total) AS costo_inventario
    FROM inventario.salidas GROUP BY factura_item_id
) sal ON sal.factura_item_id = fi.id
LEFT JOIN (
    SELECT venta_item_id, SUM(valor_total) AS costo_directo
    FROM gastos.gastos WHERE venta_item_id IS NOT NULL GROUP BY venta_item_id
) gd ON gd.venta_item_id = fi.id;

-- 4. Crear/actualizar vistas del schema inventario
CREATE OR REPLACE VIEW inventario.vw_stock_disponible AS
SELECT
    p.id AS producto_id,
    p.nombre,
    p.categoria,
    COALESCE(SUM(e.cantidad_disponible), 0) AS stock_actual
FROM inventario.productos p
LEFT JOIN inventario.entradas e ON e.producto_id = p.id
WHERE p.inventariable = TRUE
GROUP BY p.id, p.nombre, p.categoria;

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

COMMIT;

-- 5. Asegurar search_path (fuera de transacción)
ALTER ROLE maxan_user SET search_path TO facturacion, compras, inventario, gastos, cartera, usuarios, generales, helpdesk, public;
