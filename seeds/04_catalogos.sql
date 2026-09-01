-- ============================================================
-- maxan-db — seeds/04_catalogos.sql
-- Catálogos maestros de negocio (datos maestros).
--   inventario.categorias
--   gastos.clasificaciones
--   cartera.medios_pago
-- Idempotente: se puede ejecutar varias veces sin error.
-- Generado desde el dump real.
-- ============================================================

-- Categorías de inventario
INSERT INTO inventario.categorias (id, nombre)
VALUES
    (1,  'Repuestos Computadores'),
    (2,  'Accesorios Computadores'),
    (3,  'Licencias'),
    (4,  'Impresoras'),
    (5,  'Computadores'),
    (6,  'Repuestos de impresoras'),
    (7,  'Servicios'),
    (8,  'Suministros'),
    (9,  'Sistema de cámaras de seguridad'),
    (10, 'Suscripciones')
ON CONFLICT (nombre) DO NOTHING;

-- Clasificaciones de gasto
INSERT INTO gastos.clasificaciones (id, nombre)
VALUES
    (1, 'Suministros'),
    (2, 'Operacional'),
    (3, 'Administrativo'),
    (4, 'Impuestos')
ON CONFLICT (nombre) DO NOTHING;

-- Medios de pago
INSERT INTO cartera.medios_pago (id, nombre)
VALUES
    (1, 'Efectivo'),
    (2, 'Transferencia Bancaria'),
    (3, 'Cheque'),
    (4, 'Tarjeta Débito'),
    (5, 'Tarjeta Crédito'),
    (6, 'Consignación'),
    (7, 'Datafono')
ON CONFLICT (nombre) DO NOTHING;