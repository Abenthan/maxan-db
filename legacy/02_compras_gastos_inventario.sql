-- =====================================================================
-- MÓDULOS: COMPRAS, INVENTARIO, GASTOS
-- Depende de: schema facturacion (ya existente)
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS compras;
CREATE SCHEMA IF NOT EXISTS inventario;
CREATE SCHEMA IF NOT EXISTS gastos;

-- ---------------------------------------------------------------------
-- 1. COMPRAS: cabecera de factura de proveedor
-- ---------------------------------------------------------------------
CREATE TABLE compras.facturas_compra (
    id                      SERIAL PRIMARY KEY,
    tipo_documento_compra   VARCHAR(20) NOT NULL DEFAULT 'factura_electronica'
                             CHECK (tipo_documento_compra IN ('factura_electronica','documento_soporte')),

    codigo_unico_documento  VARCHAR(100) UNIQUE,
    numero_completo         VARCHAR(30) NOT NULL,
    fecha_emision           DATE NOT NULL,
    fecha_recepcion         DATE DEFAULT CURRENT_DATE,

    moneda                  VARCHAR(3) DEFAULT 'COP',
    valor_subtotal          NUMERIC(18,2) DEFAULT 0,
    valor_total_impuestos   NUMERIC(18,2) DEFAULT 0,
    valor_iva               NUMERIC(18,2) DEFAULT 0,
    valor_a_pagar            NUMERIC(18,2) NOT NULL,

    proveedor_id            INT NOT NULL REFERENCES generales.terceros(id),
    receptor_id             INT NOT NULL REFERENCES generales.terceros(id),

    estado                  VARCHAR(20) DEFAULT 'recibida'
                             CHECK (estado IN ('recibida','pendiente_pago','pagada_parcial','pagada','anulada','rechazada')),

    created_at              TIMESTAMP DEFAULT now(),
    updated_at              TIMESTAMP DEFAULT now()
);

CREATE TRIGGER trg_facturas_compra_updated_at
    BEFORE UPDATE ON compras.facturas_compra
    FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

-- Archivos asociados (XML del proveedor, PDF)
CREATE TABLE compras.facturas_compra_archivos (
    id                  SERIAL PRIMARY KEY,
    factura_compra_id   INT NOT NULL REFERENCES compras.facturas_compra(id) ON DELETE CASCADE,
    tipo_archivo        VARCHAR(20) NOT NULL
                         CHECK (tipo_archivo IN ('xml_invoice','pdf','otro')),
    nombre_archivo       VARCHAR(255),
    ruta_archivo         VARCHAR(500),
    contenido_xml        TEXT,
    hash_sha256          VARCHAR(64),
    created_at           TIMESTAMP DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 2. INVENTARIO: catálogo de productos
-- ---------------------------------------------------------------------
CREATE TABLE inventario.productos (
    id              SERIAL PRIMARY KEY,
    codigo          VARCHAR(50) NOT NULL UNIQUE,
    nombre          VARCHAR(255) NOT NULL,
    categoria       VARCHAR(100),              -- "Equipos de Cómputo", "Insumos de Impresión", etc.
    inventariable   BOOLEAN NOT NULL DEFAULT TRUE,  -- ¿afecta stock o es activo interno?
    unidad_medida   VARCHAR(10) DEFAULT 'UND',
    created_at      TIMESTAMP DEFAULT now(),
    updated_at      TIMESTAMP DEFAULT now()
);

CREATE TRIGGER trg_productos_updated_at
    BEFORE UPDATE ON inventario.productos
    FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

-- ---------------------------------------------------------------------
-- 3. CATEGORÍAS DE PRODUCTOS (maestro)
-- ---------------------------------------------------------------------
CREATE TABLE inventario.categorias (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL UNIQUE,
    created_at  TIMESTAMP DEFAULT now()
);

-- ---------------------------------------------------------------------
-- 4. GASTOS: cada línea de compra (con o sin factura formal) es un gasto
-- ---------------------------------------------------------------------
CREATE TABLE gastos.gastos (
    id                  SERIAL PRIMARY KEY,

    factura_compra_id   INT REFERENCES compras.facturas_compra(id) ON DELETE CASCADE, -- NULL = gasto suelto
    proveedor_id        INT REFERENCES generales.terceros(id),                      -- opcional si es informal

    producto_id         INT REFERENCES inventario.productos(id),     -- si es físico revendible
    venta_item_id        INT REFERENCES facturacion.ventas_items(id), -- asignación directa (solo si producto_id IS NULL)

    codigo_producto      VARCHAR(50),                                  -- código del producto en el sistema del proveedor

    descripcion          TEXT NOT NULL,
    clasificacion         VARCHAR(20) NOT NULL
                          CHECK (clasificacion IN ('Suministros','Operacional','Administrativo')),

    cantidad              NUMERIC(18,6) NOT NULL DEFAULT 1,
    valor_unitario         NUMERIC(18,2) NOT NULL,
    valor_total            NUMERIC(18,2) NOT NULL,

    fecha                  DATE NOT NULL DEFAULT CURRENT_DATE,

    created_at             TIMESTAMP DEFAULT now(),
    updated_at             TIMESTAMP DEFAULT now(),

    -- Un gasto de producto inventariable nunca se asigna directo a una venta;
    -- debe pasar por inventario (tabla de salidas)
    CHECK (NOT (producto_id IS NOT NULL AND venta_item_id IS NOT NULL))
);

CREATE INDEX idx_gastos_factura_compra ON gastos.gastos(factura_compra_id);
CREATE INDEX idx_gastos_producto       ON gastos.gastos(producto_id);
CREATE INDEX idx_gastos_venta_item     ON gastos.gastos(venta_item_id);

CREATE TRIGGER trg_gastos_updated_at
    BEFORE UPDATE ON gastos.gastos
    FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

-- Auto-asignar clasificación = 'Suministros' cuando hay producto
CREATE OR REPLACE FUNCTION gastos.fn_set_clasificacion()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.producto_id IS NOT NULL THEN
        NEW.clasificacion := 'Suministros';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_gastos_set_clasificacion
    BEFORE INSERT OR UPDATE ON gastos.gastos
    FOR EACH ROW EXECUTE FUNCTION gastos.fn_set_clasificacion();

-- ---------------------------------------------------------------------
-- 5. INVENTARIO: entradas (stock comprado) y salidas (stock vendido, FIFO)
-- ---------------------------------------------------------------------
CREATE TABLE inventario.entradas (
    id                  SERIAL PRIMARY KEY,
    gasto_id            INT NOT NULL REFERENCES gastos.gastos(id) ON DELETE CASCADE,
    producto_id         INT NOT NULL REFERENCES inventario.productos(id),
    cantidad            NUMERIC(18,6) NOT NULL,
    cantidad_disponible NUMERIC(18,6) NOT NULL,   -- se reduce al consumir vía FIFO
    costo_unitario      NUMERIC(18,2) NOT NULL,
    fecha               DATE NOT NULL,
    created_at          TIMESTAMP DEFAULT now()
);

CREATE INDEX idx_entradas_producto_fecha ON inventario.entradas(producto_id, fecha, id);

-- Auto-crear/actualizar entrada de inventario cuando el gasto tiene un producto inventariable y es Suministros
CREATE OR REPLACE FUNCTION inventario.fn_crear_entrada()
RETURNS TRIGGER AS $$
DECLARE
    v_inventariable BOOLEAN;
    v_entrada_id INT;
BEGIN
    IF NEW.producto_id IS NOT NULL AND NEW.clasificacion = 'Suministros' THEN
        SELECT inventariable INTO v_inventariable FROM inventario.productos WHERE id = NEW.producto_id;
        IF v_inventariable THEN
            SELECT id INTO v_entrada_id FROM inventario.entradas WHERE gasto_id = NEW.id;
            IF NOT FOUND THEN
                INSERT INTO inventario.entradas (gasto_id, producto_id, cantidad, cantidad_disponible, costo_unitario, fecha)
                VALUES (NEW.id, NEW.producto_id, NEW.cantidad, NEW.cantidad, NEW.valor_unitario, NEW.fecha);
            ELSE
                UPDATE inventario.entradas
                SET producto_id = NEW.producto_id,
                    cantidad = NEW.cantidad,
                    cantidad_disponible = NEW.cantidad,
                    costo_unitario = NEW.valor_unitario,
                    fecha = NEW.fecha
                WHERE id = v_entrada_id;
            END IF;
        END IF;
    ELSE
        DELETE FROM inventario.entradas WHERE gasto_id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_gastos_crear_entrada
    AFTER INSERT OR UPDATE OF producto_id ON gastos.gastos
    FOR EACH ROW EXECUTE FUNCTION inventario.fn_crear_entrada();

-- Salidas: consumo de inventario al vender (cabecera)
CREATE TABLE inventario.salidas (
    id               SERIAL PRIMARY KEY,
    factura_item_id  INT NOT NULL REFERENCES facturacion.ventas_items(id) ON DELETE CASCADE,
    producto_id      INT NOT NULL REFERENCES inventario.productos(id),
    cantidad          NUMERIC(18,6) NOT NULL,
    costo_total        NUMERIC(18,2) NOT NULL,
    created_at         TIMESTAMP DEFAULT now()
);

-- Detalle de qué entradas (lotes) se consumieron — permite FIFO repartido entre varios lotes
CREATE TABLE inventario.salida_detalle (
    id                  SERIAL PRIMARY KEY,
    salida_id           INT NOT NULL REFERENCES inventario.salidas(id) ON DELETE CASCADE,
    entrada_id           INT NOT NULL REFERENCES inventario.entradas(id),
    cantidad_consumida    NUMERIC(18,6) NOT NULL,
    costo_unitario         NUMERIC(18,2) NOT NULL   -- copiado de la entrada al momento del consumo
);

-- ---------------------------------------------------------------------
-- 6. VISTAS DE CONSULTA
-- ---------------------------------------------------------------------

-- Stock actual por producto
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

-- Utilidad por línea de venta (combina costo de inventario + costo directo de servicios)
CREATE OR REPLACE VIEW facturacion.vw_utilidad_items AS
SELECT
    fi.id AS venta_item_id,
    fi.descripcion,
    fi.valor_linea,
    fi.producto_id,
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

-- Utilidad (ingresos - costos) por producto
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

-- ---------------------------------------------------------------------
-- 8. search_path actualizado
-- ---------------------------------------------------------------------
ALTER ROLE maxan_user SET search_path TO facturacion, compras, inventario, gastos, public;