-- =====================================================================
-- MÓDULO: CARTERA Y PAGOS DE CLIENTES
-- Pagos recibidos de clientes aplicados a facturas de venta
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS cartera;

-- ---------------------------------------------------------------------
-- 1. MEDIOS DE PAGO (maestro)
-- ---------------------------------------------------------------------
CREATE TABLE cartera.medios_pago (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL UNIQUE,
    created_at  TIMESTAMP DEFAULT now()
);

INSERT INTO cartera.medios_pago (nombre) VALUES
    ('Efectivo'),
    ('Transferencia Bancaria'),
    ('Cheque'),
    ('Tarjeta Débito'),
    ('Tarjeta Crédito'),
    ('Consignación'),
    ('Datafono')
ON CONFLICT (nombre) DO NOTHING;

-- ---------------------------------------------------------------------
-- 2. PAGOS DE CLIENTES (ingresos)
-- ---------------------------------------------------------------------
CREATE TABLE cartera.pagos (
    id              SERIAL PRIMARY KEY,
    cliente_id      INT NOT NULL REFERENCES generales.terceros(id),
    medio_pago_id   INT REFERENCES cartera.medios_pago(id),
    referencia      VARCHAR(100),
    fecha_pago      DATE NOT NULL DEFAULT CURRENT_DATE,
    valor_total     NUMERIC(18,2) NOT NULL CHECK (valor_total > 0),
    observaciones   TEXT,
    anulado         BOOLEAN NOT NULL DEFAULT FALSE,
    created_at      TIMESTAMP DEFAULT now(),
    updated_at      TIMESTAMP DEFAULT now()
);

CREATE INDEX idx_pagos_cliente ON cartera.pagos(cliente_id);
CREATE INDEX idx_pagos_fecha   ON cartera.pagos(fecha_pago);

CREATE TRIGGER trg_pagos_updated_at
    BEFORE UPDATE ON cartera.pagos
    FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

-- ---------------------------------------------------------------------
-- 3. APLICACIÓN DE PAGOS A FACTURAS DE VENTA
-- ---------------------------------------------------------------------
CREATE TABLE cartera.pago_aplicaciones (
    id              SERIAL PRIMARY KEY,
    pago_id         INT NOT NULL REFERENCES cartera.pagos(id) ON DELETE CASCADE,
    venta_id        INT NOT NULL REFERENCES facturacion.ventas(id) ON DELETE CASCADE,
    valor_aplicado  NUMERIC(18,2) NOT NULL CHECK (valor_aplicado > 0),
    created_at      TIMESTAMP DEFAULT now(),
    UNIQUE (pago_id, venta_id)
);

CREATE INDEX idx_pago_aplicaciones_pago   ON cartera.pago_aplicaciones(pago_id);
CREATE INDEX idx_pago_aplicaciones_venta  ON cartera.pago_aplicaciones(venta_id);

-- ---------------------------------------------------------------------
-- 4. AGREGAR saldo_pendiente a ventas + pagada_parcial al CHECK
-- ---------------------------------------------------------------------
ALTER TABLE facturacion.ventas
    ADD COLUMN saldo_pendiente NUMERIC(18,2);

ALTER TABLE facturacion.ventas
    DROP CONSTRAINT facturas_estado_check;

ALTER TABLE facturacion.ventas
    ADD CONSTRAINT ventas_estado_check
    CHECK (estado IN ('recibida','pendiente_pago','pagada_parcial','pagada','anulada','rechazada'));

-- Inicializar saldo_pendiente = valor_a_pagar para todas las ventas no anuladas
UPDATE facturacion.ventas
SET saldo_pendiente = valor_a_pagar
WHERE saldo_pendiente IS NULL AND estado NOT IN ('anulada', 'rechazada');

-- Migrar ventas existentes de 'recibida' a 'pendiente_pago'
UPDATE facturacion.ventas
SET estado = 'pendiente_pago'
WHERE estado = 'recibida' AND saldo_pendiente > 0;

-- ---------------------------------------------------------------------
-- 5. TRIGGER: actualizar saldo_pendiente y estado al aplicar/desaplicar pagos
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION cartera.fn_actualizar_saldo()
RETURNS TRIGGER AS $$
DECLARE
    v_total_pagado NUMERIC(18,2);
    v_valor_venta  NUMERIC(18,2);
BEGIN
    IF TG_OP = 'INSERT' THEN
        UPDATE facturacion.ventas
        SET saldo_pendiente = saldo_pendiente - NEW.valor_aplicado
        WHERE id = NEW.venta_id;
    ELSIF TG_OP = 'DELETE' THEN
        UPDATE facturacion.ventas
        SET saldo_pendiente = saldo_pendiente + OLD.valor_aplicado
        WHERE id = OLD.venta_id;
    END IF;

    -- Recalcular y ajustar estado de la venta
    FOR v_valor_venta IN SELECT valor_a_pagar FROM facturacion.ventas WHERE id = COALESCE(NEW.venta_id, OLD.venta_id)
    LOOP
        SELECT COALESCE(SUM(valor_aplicado), 0) INTO v_total_pagado
        FROM cartera.pago_aplicaciones
        WHERE venta_id = COALESCE(NEW.venta_id, OLD.venta_id);

        UPDATE facturacion.ventas
        SET estado = CASE
            WHEN v_total_pagado <= 0 THEN 'pendiente_pago'
            WHEN v_total_pagado >= v_valor_venta THEN 'pagada'
            ELSE 'pagada_parcial'
        END
        WHERE id = COALESCE(NEW.venta_id, OLD.venta_id)
          AND estado NOT IN ('anulada', 'rechazada');
    END LOOP;

    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_pago_aplicaciones_actualizar_saldo
    AFTER INSERT OR DELETE ON cartera.pago_aplicaciones
    FOR EACH ROW EXECUTE FUNCTION cartera.fn_actualizar_saldo();

-- ---------------------------------------------------------------------
-- 6. VISTAS DE CONSULTA
-- ---------------------------------------------------------------------

-- Cartera activa: facturas de venta con saldo pendiente + aging
CREATE OR REPLACE VIEW cartera.vw_cartera_activa AS
SELECT
    v.id AS venta_id,
    v.numero_completo,
    v.fecha_emision,
    v.fecha_vencimiento,
    v.fecha_vencimiento_pago,
    v.valor_a_pagar,
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

-- Historial de pagos con detalle de facturas aplicadas
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

-- Detalle de aplicaciones de un pago
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

-- ---------------------------------------------------------------------
-- 7. search_path
-- ---------------------------------------------------------------------
ALTER ROLE maxan_user SET search_path TO facturacion, compras, inventario, gastos, cartera, public;
