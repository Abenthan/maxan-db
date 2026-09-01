-- =====================================================================
-- MIGRACIÓN: Retenciones por línea de venta + integración con pagos
-- =====================================================================

-- 1. Agregar columna de retención por ítem de venta
ALTER TABLE facturacion.ventas_items
ADD COLUMN valor_retencion_fuente NUMERIC(18,2) NOT NULL DEFAULT 0;

-- 2. Reemplazar trigger fn_actualizar_saldo para considerar retenciones
CREATE OR REPLACE FUNCTION cartera.fn_actualizar_saldo()
RETURNS TRIGGER AS $$
DECLARE
    v_total_pagado      NUMERIC(18,2);
    v_valor_venta       NUMERIC(18,2);
    v_total_retenciones NUMERIC(18,2);
    v_venta_id          INT;
BEGIN
    v_venta_id := COALESCE(NEW.venta_id, OLD.venta_id);

    SELECT v.valor_a_pagar INTO v_valor_venta
    FROM facturacion.ventas v WHERE v.id = v_venta_id;

    SELECT COALESCE(SUM(pa.valor_aplicado), 0) INTO v_total_pagado
    FROM cartera.pago_aplicaciones pa WHERE pa.venta_id = v_venta_id;

    SELECT COALESCE(v.valor_retencion_fuente, 0) INTO v_total_retenciones
    FROM facturacion.ventas v WHERE v.id = v_venta_id;

    UPDATE facturacion.ventas
    SET saldo_pendiente = GREATEST(v_valor_venta - v_total_pagado - v_total_retenciones, 0),
        estado = CASE
            WHEN v_total_pagado + v_total_retenciones >= v_valor_venta THEN 'pagada'
            WHEN v_total_pagado > 0 THEN 'pagada_parcial'
            ELSE 'pendiente_pago'
        END
    WHERE id = v_venta_id
      AND estado NOT IN ('anulada', 'rechazada');

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

-- 3. Actualizar vw_utilidad_items para incluir retenciones como costo
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

-- 4. Actualizar vw_cartera_activa para mostrar retenciones por factura
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
