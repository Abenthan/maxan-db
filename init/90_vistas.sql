-- ============================================================
-- maxan-db - 90_vistas.sql (generado por tools/build_init.ps1)
-- Todas las vistas (referencian tablas de varios schemas;
-- deben crearse al final, cuando existen todas las tablas).
-- ============================================================

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;
CREATE VIEW facturacion.vw_facturas_resumen AS
 SELECT v.id,
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
   FROM ((facturacion.ventas v
     JOIN generales.terceros e ON ((e.id = v.emisor_id)))
     JOIN generales.terceros r ON ((r.id = v.receptor_id)));

CREATE VIEW facturacion.vw_utilidad_items AS
 SELECT fi.id AS venta_item_id,
    fi.descripcion,
    fi.valor_linea,
    fi.producto_id,
    COALESCE(v.valor_retencion_fuente, (0)::numeric) AS valor_retencion_fuente,
    COALESCE(sal.costo_inventario, (0)::numeric) AS costo_inventario,
    COALESCE(gd.costo_directo, (0)::numeric) AS costo_directo,
    (((fi.valor_linea - COALESCE(sal.costo_inventario, (0)::numeric)) - COALESCE(gd.costo_directo, (0)::numeric)) - COALESCE(v.valor_retencion_fuente, (0)::numeric)) AS utilidad
   FROM (((facturacion.ventas_items fi
     JOIN facturacion.ventas v ON ((v.id = fi.venta_id)))
     LEFT JOIN ( SELECT salidas.factura_item_id,
            sum(salidas.costo_total) AS costo_inventario
           FROM inventario.salidas
          GROUP BY salidas.factura_item_id) sal ON ((sal.factura_item_id = fi.id)))
     LEFT JOIN ( SELECT gastos.venta_item_id,
            sum(gastos.valor_total) AS costo_directo
           FROM gastos.gastos
          WHERE (gastos.venta_item_id IS NOT NULL)
          GROUP BY gastos.venta_item_id) gd ON ((gd.venta_item_id = fi.id)));

CREATE VIEW inventario.vw_stock_disponible AS
 SELECT p.id AS producto_id,
    p.nombre,
    p.categoria,
    COALESCE(sum(e.cantidad_disponible), (0)::numeric) AS stock_actual
   FROM (inventario.productos p
     LEFT JOIN inventario.entradas e ON ((e.producto_id = p.id)))
  WHERE (p.inventariable = true)
  GROUP BY p.id, p.nombre, p.categoria;

CREATE VIEW inventario.vw_utilidad_productos AS
 SELECT p.id AS producto_id,
    p.codigo,
    p.nombre,
    p.categoria,
    COALESCE(compras.costo_adquisiciones, (0)::numeric) AS costo_adquisiciones,
    COALESCE(ventas.ingreso_ventas, (0)::numeric) AS ingreso_ventas,
    COALESCE(gastos_extra.otros_costos, (0)::numeric) AS otros_costos,
    ((COALESCE(ventas.ingreso_ventas, (0)::numeric) - COALESCE(compras.costo_adquisiciones, (0)::numeric)) - COALESCE(gastos_extra.otros_costos, (0)::numeric)) AS utilidad
   FROM (((inventario.productos p
     LEFT JOIN ( SELECT e.producto_id,
            sum((e.cantidad * e.costo_unitario)) AS costo_adquisiciones
           FROM inventario.entradas e
          GROUP BY e.producto_id) compras ON ((compras.producto_id = p.id)))
     LEFT JOIN ( SELECT s.producto_id,
            sum(vi.valor_linea) AS ingreso_ventas
           FROM (inventario.salidas s
             JOIN facturacion.ventas_items vi ON ((vi.id = s.factura_item_id)))
          GROUP BY s.producto_id) ventas ON ((ventas.producto_id = p.id)))
     LEFT JOIN ( SELECT g.producto_id,
            sum(g.valor_total) AS otros_costos
           FROM gastos.gastos g
          WHERE ((g.producto_id IS NOT NULL) AND (g.venta_item_id IS NULL) AND ((g.clasificacion)::text <> 'Suministros'::text))
          GROUP BY g.producto_id) gastos_extra ON ((gastos_extra.producto_id = p.id)))
  ORDER BY p.nombre;

CREATE VIEW cartera.vw_cartera_activa AS
 SELECT v.id AS venta_id,
    v.numero_completo,
    v.fecha_emision,
    v.fecha_vencimiento,
    v.fecha_vencimiento_pago,
    v.valor_a_pagar,
    v.valor_retencion_fuente,
    (v.valor_a_pagar - COALESCE(v.saldo_pendiente, (0)::numeric)) AS total_pagado,
    COALESCE(v.saldo_pendiente, v.valor_a_pagar) AS saldo_pendiente,
    t.id AS cliente_id,
    t.razon_social AS cliente,
    t.numero_documento AS nit_cliente,
    v.estado,
        CASE
            WHEN (COALESCE(v.saldo_pendiente, v.valor_a_pagar) <= (0)::numeric) THEN 'Pagada'::text
            WHEN (v.fecha_vencimiento_pago IS NULL) THEN 'Sin vencimiento'::text
            WHEN (CURRENT_DATE > v.fecha_vencimiento_pago) THEN 'Vencida'::text
            ELSE 'Al día'::text
        END AS estado_cartera,
        CASE
            WHEN (COALESCE(v.saldo_pendiente, v.valor_a_pagar) <= (0)::numeric) THEN 0
            WHEN (v.fecha_vencimiento_pago IS NULL) THEN 0
            WHEN (CURRENT_DATE <= v.fecha_vencimiento_pago) THEN 0
            WHEN ((CURRENT_DATE - v.fecha_vencimiento_pago) <= 30) THEN 30
            WHEN ((CURRENT_DATE - v.fecha_vencimiento_pago) <= 60) THEN 60
            WHEN ((CURRENT_DATE - v.fecha_vencimiento_pago) <= 90) THEN 90
            ELSE 999
        END AS dias_vencida
   FROM (facturacion.ventas v
     JOIN generales.terceros t ON ((t.id = v.receptor_id)))
  WHERE ((v.estado)::text <> ALL ((ARRAY['anulada'::character varying, 'rechazada'::character varying])::text[]))
  ORDER BY v.fecha_vencimiento_pago, v.fecha_emision DESC;

CREATE VIEW cartera.vw_pago_detalle AS
 SELECT pa.id AS aplicacion_id,
    pa.pago_id,
    pa.venta_id,
    pa.valor_aplicado,
    pa.created_at AS fecha_aplicacion,
    v.numero_completo AS factura_numero,
    v.fecha_emision AS factura_fecha,
    v.valor_a_pagar AS factura_valor
   FROM (cartera.pago_aplicaciones pa
     JOIN facturacion.ventas v ON ((v.id = pa.venta_id)));

CREATE VIEW cartera.vw_pagos_resumen AS
 SELECT p.id,
    p.fecha_pago,
    p.valor_total,
    p.referencia,
    p.anulado,
    mp.nombre AS medio_pago,
    t.id AS cliente_id,
    t.razon_social AS cliente,
    t.numero_documento AS nit_cliente,
    COALESCE(pa.facturas_aplicadas, (0)::bigint) AS facturas_aplicadas,
    COALESCE(pa.total_aplicado, (0)::numeric) AS total_aplicado,
        CASE
            WHEN (COALESCE(pa.total_aplicado, (0)::numeric) < p.valor_total) THEN (p.valor_total - COALESCE(pa.total_aplicado, (0)::numeric))
            ELSE (0)::numeric
        END AS sin_aplicar
   FROM (((cartera.pagos p
     JOIN generales.terceros t ON ((t.id = p.cliente_id)))
     LEFT JOIN cartera.medios_pago mp ON ((mp.id = p.medio_pago_id)))
     LEFT JOIN ( SELECT pago_aplicaciones.pago_id,
            count(*) AS facturas_aplicadas,
            sum(pago_aplicaciones.valor_aplicado) AS total_aplicado
           FROM cartera.pago_aplicaciones
          GROUP BY pago_aplicaciones.pago_id) pa ON ((pa.pago_id = p.id)))
  ORDER BY p.fecha_pago DESC, p.id DESC;
