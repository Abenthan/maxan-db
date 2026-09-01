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
