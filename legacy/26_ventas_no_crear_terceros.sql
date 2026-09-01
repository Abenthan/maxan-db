-- =====================================================================
-- MIGRACIÓN 26: El proceso de venta ya no crea terceros
-- El backend ahora reutiliza exclusivamente terceros existentes
-- (por id, por documento o por razon_social). Para que la venta
-- por defecto "Ventas sin factura" (CC 123456789) siga funcionando
-- en BD vacías, se asegura de que ese tercero exista.
-- =====================================================================

INSERT INTO generales.terceros (tipo_documento, numero_documento, razon_social, es_cliente)
VALUES ('13', '123456789', 'Ventas sin factura', true)
ON CONFLICT (tipo_documento, numero_documento)
DO UPDATE SET
  razon_social = EXCLUDED.razon_social,
  es_cliente = true,
  updated_at = now();