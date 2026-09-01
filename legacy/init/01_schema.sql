-- =====================================================================
-- ESQUEMA DE BASE DE DATOS: SISTEMA DE FACTURAS ELECTRÓNICAS DIAN
-- PostgreSQL 14+
-- Diseñado a partir de la estructura UBL 2.1 / DIAN 2.1
-- (AttachedDocument + Invoice + ApplicationResponse)
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS facturacion;
CREATE SCHEMA IF NOT EXISTS generales;
SET search_path TO facturacion;

-- ---------------------------------------------------------------------
-- 1. TERCEROS (emisores y receptores: clientes, proveedores, tú mismo)
-- ---------------------------------------------------------------------
CREATE TABLE generales.terceros (
    id                  SERIAL PRIMARY KEY,
    tipo_documento      VARCHAR(5),                   -- schemeID DIAN: 13=NIT, 31=NIT jurídico, etc.
    numero_documento    VARCHAR(20),
    digito_verificacion VARCHAR(1),
    tipo_persona        VARCHAR(20),                  -- 'Natural' / 'Jurídica'
    razon_social        VARCHAR(255) NOT NULL,
    direccion           VARCHAR(255),
    codigo_ciudad       VARCHAR(10),
    ciudad              VARCHAR(100),
    codigo_departamento VARCHAR(10),
    departamento        VARCHAR(100),
    codigo_postal       VARCHAR(10),
    pais                VARCHAR(2)   DEFAULT 'CO',
    telefono            VARCHAR(50),
    email               VARCHAR(150),
    es_propio           BOOLEAN      DEFAULT FALSE,    -- true = es tu propia empresa (Maxan, etc.)
    created_at          TIMESTAMP    DEFAULT now(),
    updated_at          TIMESTAMP    DEFAULT now(),
    UNIQUE (tipo_documento, numero_documento)
);

-- ---------------------------------------------------------------------
-- 2. FACTURAS (cabecera del documento)
-- ---------------------------------------------------------------------
CREATE TABLE facturas (
    id                          SERIAL PRIMARY KEY,

    -- Identificación del documento
    cufe                        VARCHAR(100) NOT NULL UNIQUE,   -- UUID/CUFE-SHA384
    prefijo                     VARCHAR(10),
    numero                      VARCHAR(20),
    numero_completo             VARCHAR(30)  NOT NULL,          -- ej: AB753 (cbc:ID)
    tipo_documento_code         VARCHAR(5),                     -- InvoiceTypeCode (01 = factura venta)
    customization_id            VARCHAR(10),                    -- 10 = Factura Electrónica Venta

    -- Fechas
    fecha_emision               DATE         NOT NULL,
    hora_emision                TIME,
    fecha_vencimiento           DATE,

    -- Moneda y totales
    moneda                      VARCHAR(3)   DEFAULT 'COP',
    valor_subtotal              NUMERIC(18,2) DEFAULT 0,
    valor_descuento             NUMERIC(18,2) DEFAULT 0,
    valor_recargo               NUMERIC(18,2) DEFAULT 0,
    valor_total_bruto           NUMERIC(18,2) DEFAULT 0,
    valor_total_impuestos       NUMERIC(18,2) DEFAULT 0,
    valor_iva                   NUMERIC(18,2) DEFAULT 0,
    valor_inc                   NUMERIC(18,2) DEFAULT 0,
    valor_ica                   NUMERIC(18,2) DEFAULT 0,
    valor_total_neto            NUMERIC(18,2) DEFAULT 0,
    valor_retencion_fuente      NUMERIC(18,2) DEFAULT 0,
    valor_retencion_iva         NUMERIC(18,2) DEFAULT 0,
    valor_retencion_ica         NUMERIC(18,2) DEFAULT 0,
    valor_anticipos             NUMERIC(18,2) DEFAULT 0,
    valor_a_pagar               NUMERIC(18,2) NOT NULL,

    -- Partes involucradas
    emisor_id                   INT NOT NULL REFERENCES generales.terceros(id),
    receptor_id                 INT NOT NULL REFERENCES generales.terceros(id),

    -- Resolución de facturación (DIAN InvoiceControl)
    resolucion_numero           VARCHAR(50),
    resolucion_fecha_desde      DATE,
    resolucion_fecha_hasta      DATE,
    resolucion_prefijo          VARCHAR(10),
    resolucion_rango_desde      VARCHAR(20),
    resolucion_rango_hasta      VARCHAR(20),

    -- Pago
    medio_pago_code             VARCHAR(10),             -- PaymentMeansCode (1 = crédito, etc.)
    fecha_vencimiento_pago      DATE,

    -- Información adicional / período
    periodo_facturacion         VARCHAR(255),

    -- QR y validación DIAN
    qr_code                     TEXT,
    codigo_respuesta_dian       VARCHAR(10),             -- ResponseCode del DocumentResponse (02 = validado)
    descripcion_respuesta_dian  VARCHAR(255),
    estado_validacion_dian      VARCHAR(10),              -- ValidationResultCode
    fecha_validacion_dian       DATE,
    hora_validacion_dian        TIME,

    -- Estado interno del flujo de negocio (no DIAN)
    estado                      VARCHAR(20) DEFAULT 'recibida'
                                 CHECK (estado IN ('recibida','pendiente_pago','pagada','anulada','rechazada')),

    -- Trazabilidad
    created_at                  TIMESTAMP DEFAULT now(),
    updated_at                  TIMESTAMP DEFAULT now()
);

CREATE INDEX idx_facturas_emisor   ON facturas(emisor_id);
CREATE INDEX idx_facturas_receptor ON facturas(receptor_id);
CREATE INDEX idx_facturas_fecha    ON facturas(fecha_emision);
CREATE INDEX idx_facturas_estado   ON facturas(estado);

-- ---------------------------------------------------------------------
-- 3. ITEMS / LÍNEAS DE FACTURA
-- ---------------------------------------------------------------------
CREATE TABLE factura_items (
    id                   SERIAL PRIMARY KEY,
    factura_id           INT NOT NULL REFERENCES facturas(id) ON DELETE CASCADE,
    numero_linea         INT NOT NULL,
    descripcion          TEXT NOT NULL,
    codigo_producto      VARCHAR(50),
    cantidad             NUMERIC(18,6) NOT NULL DEFAULT 1,
    unidad_medida        VARCHAR(10),                 -- NIU, UND, etc.
    valor_unitario       NUMERIC(18,2) NOT NULL,
    porcentaje_descuento NUMERIC(5,2) DEFAULT 0,
    valor_descuento      NUMERIC(18,2) DEFAULT 0,
    valor_linea          NUMERIC(18,2) NOT NULL,
    UNIQUE (factura_id, numero_linea)
);

-- ---------------------------------------------------------------------
-- 4. IMPUESTOS POR LÍNEA (IVA, ICA, INC, etc. - generalizado)
-- ---------------------------------------------------------------------
CREATE TABLE factura_impuestos (
    id               SERIAL PRIMARY KEY,
    factura_id       INT NOT NULL REFERENCES facturas(id) ON DELETE CASCADE,
    factura_item_id  INT REFERENCES factura_items(id) ON DELETE CASCADE,  -- NULL = impuesto a nivel factura
    tipo_impuesto    VARCHAR(10) NOT NULL,   -- 01=IVA, 04=ICA, 03=INC...
    nombre_impuesto  VARCHAR(50),
    porcentaje       NUMERIC(5,2) DEFAULT 0,
    base_gravable    NUMERIC(18,2) DEFAULT 0,
    valor            NUMERIC(18,2) DEFAULT 0
);

-- ---------------------------------------------------------------------
-- 5. RESPUESTAS / VALIDACIONES DE LA DIAN (detalle por línea)
-- ---------------------------------------------------------------------
CREATE TABLE factura_respuestas_dian (
    id              SERIAL PRIMARY KEY,
    factura_id      INT NOT NULL REFERENCES facturas(id) ON DELETE CASCADE,
    linea_id        INT,
    codigo_respuesta VARCHAR(10),
    descripcion      TEXT
);

-- ---------------------------------------------------------------------
-- 6. ARCHIVOS ASOCIADOS (XML AttachedDocument, XML Invoice, PDF, etc.)
-- ---------------------------------------------------------------------
CREATE TABLE factura_archivos (
    id              SERIAL PRIMARY KEY,
    factura_id      INT NOT NULL REFERENCES facturas(id) ON DELETE CASCADE,
    tipo_archivo    VARCHAR(20) NOT NULL
                    CHECK (tipo_archivo IN ('xml_attached_document','xml_invoice','xml_application_response','pdf','otro')),
    nombre_archivo  VARCHAR(255),
    ruta_archivo    VARCHAR(500),         -- ruta en disco / bucket (S3, Drive, etc.)
    contenido_xml   TEXT,                 -- opcional: guardar el XML completo si no usas almacenamiento externo
    hash_sha256     VARCHAR(64),
    created_at      TIMESTAMP DEFAULT now()
);

-- ---------------------------------------------------------------------
-- TRIGGER: actualizar updated_at automáticamente
-- ---------------------------------------------------------------------
CREATE OR REPLACE FUNCTION fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER trg_facturas_updated_at
    BEFORE UPDATE ON facturas
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

CREATE TRIGGER trg_terceros_updated_at
    BEFORE UPDATE ON generales.terceros
    FOR EACH ROW EXECUTE FUNCTION fn_set_updated_at();

-- ---------------------------------------------------------------------
-- VISTA DE CONSULTA RÁPIDA: facturas con nombres de emisor/receptor
-- ---------------------------------------------------------------------
CREATE OR REPLACE VIEW vw_facturas_resumen AS
SELECT
    f.id,
    f.numero_completo,
    f.cufe,
    f.fecha_emision,
    f.fecha_vencimiento,
    e.razon_social AS emisor,
    e.numero_documento AS nit_emisor,
    r.razon_social AS receptor,
    r.numero_documento AS nit_receptor,
    f.valor_a_pagar,
    f.estado,
    f.codigo_respuesta_dian,
    f.estado_validacion_dian
FROM facturas f
JOIN generales.terceros e ON e.id = f.emisor_id
JOIN generales.terceros r ON r.id = f.receptor_id;


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
    gasto_id            INT REFERENCES gastos.gastos(id) ON DELETE CASCADE, -- NULL = ingreso manual
    producto_id         INT NOT NULL REFERENCES inventario.productos(id),
    cantidad            NUMERIC(18,6) NOT NULL,
    cantidad_disponible NUMERIC(18,6) NOT NULL,   -- se reduce al consumir vía FIFO
    costo_unitario      NUMERIC(18,2) NOT NULL,
    fecha               DATE NOT NULL,
    origen              VARCHAR(20) NOT NULL DEFAULT 'gasto', -- 'gasto' | 'inicial' | 'ajuste' | 'otro'
    referencia          TEXT,                                 -- observación opcional
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

-- =====================================================================
-- MIGRACIÓN: Agregar código único a productos
-- =====================================================================

ALTER TABLE inventario.productos ADD COLUMN codigo VARCHAR(50);

UPDATE inventario.productos SET codigo = 'PROD-' || LPAD(id::text, 4, '0') WHERE codigo IS NULL;

ALTER TABLE inventario.productos ALTER COLUMN codigo SET NOT NULL;
ALTER TABLE inventario.productos ADD CONSTRAINT uq_productos_codigo UNIQUE (codigo);


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


-- =====================================================================
-- MIGRACIÓN: Categorias de productos + codigo_producto en gastos
-- =====================================================================

CREATE TABLE IF NOT EXISTS inventario.categorias (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT now()
);

ALTER TABLE gastos.gastos ADD COLUMN codigo_producto VARCHAR(50);


-- =====================================================================
-- MIGRACIÓN: Trigger crea/actualiza entrada de inventario también en UPDATE
-- =====================================================================

CREATE OR REPLACE FUNCTION inventario.fn_crear_entrada()
RETURNS TRIGGER AS $$
DECLARE
    v_inventariable BOOLEAN;
    v_entrada_id INT;
BEGIN
    IF NEW.producto_id IS NOT NULL THEN
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

DROP TRIGGER IF EXISTS trg_gastos_crear_entrada ON gastos.gastos;

CREATE TRIGGER trg_gastos_crear_entrada
    AFTER INSERT OR UPDATE OF producto_id ON gastos.gastos
    FOR EACH ROW EXECUTE FUNCTION inventario.fn_crear_entrada();


-- =====================================================================
-- MIGRACIÓN: Solo crear/actualizar entrada de inventario si clasificacion = 'Suministros'
-- =====================================================================

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
ALTER ROLE maxan_user SET search_path TO facturacion, compras, inventario, gastos, cartera, usuarios, generales, helpdesk, public;


-- =====================================================================
-- MIGRACIÓN: Tabla de clasificaciones de gastos (maestro, como categorías)
-- =====================================================================

CREATE TABLE IF NOT EXISTS gastos.clasificaciones (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(50) NOT NULL UNIQUE,
    created_at  TIMESTAMP DEFAULT now()
);

INSERT INTO gastos.clasificaciones (nombre) VALUES
    ('Suministros'),
    ('Operacional'),
    ('Administrativo')
ON CONFLICT (nombre) DO NOTHING;

ALTER TABLE gastos.gastos DROP CONSTRAINT IF EXISTS gastos_clasificacion_check;
ALTER TABLE gastos.gastos DROP CONSTRAINT IF EXISTS gastos_gastos_clasificacion_check;
ALTER TABLE gastos.gastos DROP CONSTRAINT IF EXISTS fk_gasto_clasificacion;

ALTER TABLE gastos.gastos
    ADD CONSTRAINT fk_gasto_clasificacion
    FOREIGN KEY (clasificacion)
    REFERENCES gastos.clasificaciones(nombre);


ALTER TABLE facturacion.ventas ALTER COLUMN cufe DROP NOT NULL;


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


ALTER TABLE facturacion.ventas
ADD COLUMN observaciones TEXT;


CREATE SEQUENCE IF NOT EXISTS facturacion.ventas_manual_seq START 1;


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


CREATE SCHEMA IF NOT EXISTS usuarios;

CREATE TABLE usuarios.empresas (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL,
  nit VARCHAR(50) UNIQUE NOT NULL,
  activa BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER trg_empresas_updated_at
  BEFORE UPDATE ON usuarios.empresas
  FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

CREATE TABLE usuarios.usuarios (
  id SERIAL PRIMARY KEY,
  empresa_id INTEGER NOT NULL REFERENCES usuarios.empresas(id),
  username VARCHAR(100) UNIQUE NOT NULL,
  email VARCHAR(255) UNIQUE NOT NULL,
  password_hash VARCHAR(255) NOT NULL,
  nombres VARCHAR(255) NOT NULL,
  apellidos VARCHAR(255) NOT NULL,
  activo BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER trg_usuarios_updated_at
  BEFORE UPDATE ON usuarios.usuarios
  FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

CREATE TABLE usuarios.roles (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(100) UNIQUE NOT NULL,
  descripcion TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE usuarios.permisos (
  id SERIAL PRIMARY KEY,
  codigo VARCHAR(100) UNIQUE NOT NULL,
  nombre VARCHAR(255) NOT NULL,
  descripcion TEXT,
  modulo VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE usuarios.roles_permisos (
  rol_id INTEGER NOT NULL REFERENCES usuarios.roles(id) ON DELETE CASCADE,
  permiso_id INTEGER NOT NULL REFERENCES usuarios.permisos(id) ON DELETE CASCADE,
  PRIMARY KEY (rol_id, permiso_id)
);

CREATE TABLE usuarios.usuarios_roles (
  usuario_id INTEGER NOT NULL REFERENCES usuarios.usuarios(id) ON DELETE CASCADE,
  rol_id INTEGER NOT NULL REFERENCES usuarios.roles(id) ON DELETE CASCADE,
  PRIMARY KEY (usuario_id, rol_id)
);


-- ============================================================
-- Módulo Helpdesk - Gestión de recursos informáticos de clientes
-- y mantenimientos / casos de soporte
-- ============================================================

CREATE SCHEMA IF NOT EXISTS helpdesk;

-- ------------------------------------------------------------------
-- 1. CATEGORÍAS DE MANTENIMIENTO
-- ------------------------------------------------------------------
CREATE TABLE helpdesk.categorias_mantenimiento (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL UNIQUE,
  color VARCHAR(7) DEFAULT '#6B7280'
);

INSERT INTO helpdesk.categorias_mantenimiento (nombre, color) VALUES
  ('Mantenimiento Preventivo', '#10B981'),
  ('Mantenimiento Correctivo', '#EF4444'),
  ('Instalación / Configuración', '#3B82F6'),
  ('Diagnóstico', '#F59E0B'),
  ('Soporte Remoto', '#8B5CF6'),
  ('Formateo / Backup', '#EC4899'),
  ('Redes / Cableado', '#14B8A6');

-- ------------------------------------------------------------------
-- 2. RECURSOS (equipos informáticos de clientes)
-- ------------------------------------------------------------------
CREATE TABLE helpdesk.recursos (
  id SERIAL PRIMARY KEY,
  cliente_id INTEGER NOT NULL REFERENCES generales.terceros(id),
  nombre VARCHAR(200) NOT NULL,
  tipo VARCHAR(50) NOT NULL DEFAULT 'Computador'
    CHECK (tipo IN ('Computador', 'Hosting', 'Office 365', 'Red', 'Celular', 'Impresora', 'Servidor', 'UPS', 'Cámara', 'Otro')),
  marca VARCHAR(100),
  modelo VARCHAR(100),
  referencia VARCHAR(100),
  serial VARCHAR(100) UNIQUE,
  procesador VARCHAR(200),
  memoria_gb NUMERIC(6,1),
  almacenamiento_gb NUMERIC(8,1),
  sistema_operativo VARCHAR(100),
  ubicacion VARCHAR(200),
  descripcion TEXT,
  activo BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER trg_recursos_updated_at
  BEFORE UPDATE ON helpdesk.recursos
  FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

-- ------------------------------------------------------------------
-- 3. MANTENIMIENTOS (tickets / casos de soporte)
-- ------------------------------------------------------------------
CREATE TABLE helpdesk.mantenimientos (
  id SERIAL PRIMARY KEY,
  recurso_id INTEGER NOT NULL REFERENCES helpdesk.recursos(id),
  categoria_id INTEGER NOT NULL REFERENCES helpdesk.categorias_mantenimiento(id),
  tecnico_id INTEGER REFERENCES usuarios.usuarios(id),
  titulo VARCHAR(300) NOT NULL,
  descripcion TEXT,
  prioridad VARCHAR(20) DEFAULT 'Media'
    CHECK (prioridad IN ('Baja', 'Media', 'Alta', 'Crítica')),
  estado VARCHAR(20) DEFAULT 'Pendiente'
    CHECK (estado IN ('Pendiente', 'En Progreso', 'Completado', 'Facturado', 'Cancelado')),
  fecha_solicitud DATE DEFAULT CURRENT_DATE,
  fecha_ejecucion DATE,
  hora_inicio TIME,
  hora_fin TIME,
  costo_mano_obra NUMERIC(12,2) DEFAULT 0,
  costo_repuestos NUMERIC(12,2) DEFAULT 0,
  costo_total NUMERIC(12,2) GENERATED ALWAYS AS (costo_mano_obra + costo_repuestos) STORED,
  venta_item_id INTEGER REFERENCES facturacion.ventas_items(id),
  observaciones TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER trg_mantenimientos_updated_at
  BEFORE UPDATE ON helpdesk.mantenimientos
  FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

-- ------------------------------------------------------------------
-- 4. DETALLES / BITÁCORA DEL MANTENIMIENTO
-- ------------------------------------------------------------------
CREATE TABLE helpdesk.mantenimiento_detalles (
  id SERIAL PRIMARY KEY,
  mantenimiento_id INTEGER NOT NULL REFERENCES helpdesk.mantenimientos(id) ON DELETE CASCADE,
  creado_por INTEGER REFERENCES usuarios.usuarios(id),
  contenido TEXT NOT NULL,
  tipo VARCHAR(20) DEFAULT 'Comentario'
    CHECK (tipo IN ('Comentario', 'Diagnóstico', 'Solución', 'Repuesto', 'Acuerdo')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ================================================================
-- SEED: TERCEROS (clientes desde Notion)
-- ================================================================
INSERT INTO generales.terceros (tipo_documento, numero_documento, razon_social) VALUES
  ('31', '900000001', 'Gestión Calidad'),
  ('31', '900000002', 'Transglobal de Carga'),
  ('31', '900000003', 'Montacargas y Transportes'),
  ('31', '900000004', 'Promatel'),
  ('31', '900000005', 'Grupo Carpini'),
  ('31', '900000006', 'Símbolo'),
  ('31', '900000007', 'Bekko'),
  ('31', '900000008', 'M2 Contable'),
  ('31', '900000009', 'Ankaras'),
  ('31', '900000010', 'Agregados Antioquia'),
  ('31', '900000011', 'Tysi'),
  ('31', '900000012', 'Serfletar'),
  ('31', '900000013', 'Express Labels'),
  ('31', '900000014', 'AMUC')
ON CONFLICT (tipo_documento, numero_documento) WHERE tipo_documento IS NOT NULL AND numero_documento IS NOT NULL DO NOTHING;

-- ================================================================
-- SEED: RECURSOS desde Notion
-- ================================================================
DO $$
DECLARE
  v_gestion_calidad   INT := (SELECT id FROM generales.terceros WHERE numero_documento = '900000001');
  v_transglobal       INT := (SELECT id FROM generales.terceros WHERE numero_documento = '900000002');
  v_montacargas       INT := (SELECT id FROM generales.terceros WHERE numero_documento = '900000003');
  v_promatel          INT := (SELECT id FROM generales.terceros WHERE numero_documento = '900000004');
  v_grupo_carpini     INT := (SELECT id FROM generales.terceros WHERE numero_documento = '900000005');
  v_simbolo           INT := (SELECT id FROM generales.terceros WHERE numero_documento = '900000006');
  v_bekko             INT := (SELECT id FROM generales.terceros WHERE numero_documento = '900000007');
  v_m2_contable       INT := (SELECT id FROM generales.terceros WHERE numero_documento = '900000008');
  v_ankaras           INT := (SELECT id FROM generales.terceros WHERE numero_documento = '900000009');
BEGIN

  -- Gestión Calidad
  INSERT INTO helpdesk.recursos (cliente_id, nombre, tipo, marca, modelo, serial, descripcion) VALUES
    (v_gestion_calidad, 'Lenovo Andres Cortez',   'Computador', 'Lenovo', 'IdeaPad 3 15IRH10', NULL,       NULL),
    (v_gestion_calidad, 'Lenovo Subey Tatiana',   'Computador', 'Lenovo', 'IdeaPad Slim 3 15IRH10', 'PF68N6RS', NULL),
    (v_gestion_calidad, 'Lenovo Shirley',         'Computador', 'Lenovo', 'IdeaPad 3 15IIL05', 'PF28BJH4',  NULL),
    (v_gestion_calidad, 'HP 14 - Leidy Rodriguez','Computador', 'HP',     'HP 14',              NULL,       NULL),
    (v_gestion_calidad, 'Lenovo Thinkbook Sergio','Computador', 'Lenovo','Thinkbook',          'LR0EYTBH', NULL),
    (v_gestion_calidad, 'Lenovo ideapad 3 - Cindy Betancur','Computador','Lenovo','IdeaPad 3','PF3TE30J', NULL),
    (v_gestion_calidad, 'Lenovo S145 - Yazmin',   'Computador', 'Lenovo', 'S145',               'PF32XNZ3', NULL),
    (v_gestion_calidad, 'Lenovo IdeaPad 3 - Subey','Computador','Lenovo','IdeaPad 3',           'PF369BYV', NULL);

  -- Transglobal de Carga
  INSERT INTO helpdesk.recursos (cliente_id, nombre, tipo, marca, modelo, serial, descripcion) VALUES
    (v_transglobal, 'Veronica Gestion Calidad',   'Computador', NULL,     NULL,                  NULL,       NULL),
    (v_transglobal, 'PC08 - Seguridad',           'Computador', 'DELL',   'Vostro 3458',         '20Z8VF2',  NULL);

  -- Montacargas y Transportes
  INSERT INTO helpdesk.recursos (cliente_id, nombre, tipo, marca, modelo, serial, descripcion) VALUES
    (v_montacargas, 'PC15 - Logistica2',             'Computador', 'DELL',         'Vostro 14 3000',       '3WC9RM3',     NULL),
    (v_montacargas, 'PC18 - Logistica1',             'Computador', 'ASUS',         'VivoBook X409DA_M409DA','L9N0CV059128376', NULL),
    (v_montacargas, 'PC04 - Gerencia Administrativa','Computador', 'HP',           NULL,                    'CND31328D8',  'PC02 - Portatil HP - Johan'),
    (v_montacargas, 'HP Logistica4',                 'Computador', 'HP',           '245 G9',                '5CG4074Y5F',  NULL),
    (v_montacargas, 'PC Logistica3',                 'Computador', 'HP',           '245G10',                '5CG438064',   NULL),
    (v_montacargas, 'PC17 - Coordinador Mantenimiento','Computador','HP',          NULL,                    '5CD2403831',  'PC17 - Portatil HP - Julian Vergara'),
    (v_montacargas, 'PC016 - Compras',               'Computador', NULL,           NULL,                    '5CG21721CN',  NULL);

  -- Promatel
  INSERT INTO helpdesk.recursos (cliente_id, nombre, tipo, marca, modelo, serial, descripcion) VALUES
    (v_promatel, 'PC Sodimac',          'Computador', NULL,    NULL,                   NULL,           'CPU Facturación Home Center'),
    (v_promatel, 'Portátil HP (Cartera)','Computador','HP',    '245 G8',               '5CG1320LKW',   NULL),
    (v_promatel, 'HP AIO Cartera',      'Computador', 'HP',   'AIO 22-DF0007LA',      '8CC1190PNZ',   NULL),
    (v_promatel, 'Tesorería PC',        'Computador', NULL,    NULL,                   NULL,           NULL),
    (v_promatel, 'Hosting Promatel',    'Hosting',    NULL,    NULL,                   NULL,           'Hosting página web');

  -- Grupo Carpini
  INSERT INTO helpdesk.recursos (cliente_id, nombre, tipo, marca, modelo, serial, descripcion) VALUES
    (v_grupo_carpini, 'HP AIO AuxContable','Computador','HP', 'AIO 24-F013LA',       '8CC92326S8',   NULL),
    (v_grupo_carpini, 'Construcción 4',    'Computador',NULL, NULL,                   NULL,           NULL),
    (v_grupo_carpini, 'Comercial 2',       'Computador',NULL, NULL,                   NULL,           NULL),
    (v_grupo_carpini, 'Construcción 2',    'Computador',NULL, NULL,                   NULL,           NULL);

  -- Símbolo
  INSERT INTO helpdesk.recursos (cliente_id, nombre, tipo, marca, modelo, serial, descripcion) VALUES
    (v_simbolo, 'Access Point TP Link',   'Red',      'TP-Link', NULL,   NULL,            'SSID: Simbolo 5G'),
    (v_simbolo, 'HP Juan Diego',          'Computador','HP',      NULL,  NULL,            NULL),
    (v_simbolo, 'ASUS X543UA - Yuliana Rua','Computador','ASUS','X543UA', 'MAN0CX23J75443D', NULL),
    (v_simbolo, 'Computador 1',           'Computador',NULL,      NULL,  NULL,            NULL),
    (v_simbolo, 'Asus JuanFdo',           'Computador','ASUS',    NULL, 'L8N0LP01F492334', NULL),
    (v_simbolo, 'Acer A514',             'Computador','Acer',    'A514', NULL,            NULL);

  -- Bekko
  INSERT INTO helpdesk.recursos (cliente_id, nombre, tipo, marca, modelo, serial, descripcion) VALUES
    (v_bekko, 'ASUS Vivobook 14', 'Computador', 'ASUS', 'Vivobook 14', 'M1N0CX023456012', NULL);

  -- M2 Contable
  INSERT INTO helpdesk.recursos (cliente_id, nombre, tipo, serial, descripcion) VALUES
    (v_m2_contable, 'Office 365 personal', 'Office 365', NULL, 'Suscripción anual');

  -- Ankaras
  INSERT INTO helpdesk.recursos (cliente_id, nombre, tipo, marca, modelo, serial) VALUES
    (v_ankaras, 'ASUS X415', 'Computador', 'ASUS', 'X415', 'R2N0CV09X683088', NULL);

END $$;


-- Agrega columna JSONB para atributos variables por tipo de recurso
ALTER TABLE helpdesk.recursos ADD COLUMN IF NOT EXISTS atributos JSONB DEFAULT '{}';


-- ============================================================
-- Módulo Helpdesk - Extensión: Casos de soporte, contactos
-- ============================================================

-- ------------------------------------------------------------------
-- 1. CATEGORÍAS DE CASO (editables por el usuario)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS helpdesk.categorias_caso (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL UNIQUE,
  color VARCHAR(7) DEFAULT '#6B7280',
  activo BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO helpdesk.categorias_caso (nombre, color) VALUES
  ('Soporte Técnico', '#3B82F6'),
  ('Falla / Error', '#EF4444'),
  ('Instalación', '#10B981'),
  ('Consulta', '#F59E0B'),
  ('Mantenimiento', '#8B5CF6'),
  ('Configuración', '#14B8A6'),
  ('Otro', '#6B7280')
ON CONFLICT (nombre) DO NOTHING;

-- ------------------------------------------------------------------
-- 2. SCHEMA GENERALES (tables shared across modules)
-- ------------------------------------------------------------------
CREATE SCHEMA IF NOT EXISTS generales;
-- ------------------------------------------------------------------
-- 3. CONTACTOS (personas de contacto de clientes)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS generales.contactos (
  id SERIAL PRIMARY KEY,
  cliente_id INTEGER REFERENCES generales.terceros(id) ON DELETE CASCADE,
  nombre VARCHAR(200) NOT NULL,
  telefono VARCHAR(50),
  email VARCHAR(200),
  whatsapp VARCHAR(50),
  cargo VARCHAR(200),
  activo BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_contactos_updated_at ON generales.contactos;
CREATE TRIGGER trg_contactos_updated_at
  BEFORE UPDATE ON generales.contactos
  FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();


-- ------------------------------------------------------------------
-- 3. CASOS (tickets de soporte)
-- ------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS helpdesk.caso_numero_seq START 1;

CREATE TABLE IF NOT EXISTS helpdesk.casos (
  id SERIAL PRIMARY KEY,
  numero VARCHAR(20) UNIQUE DEFAULT ('CASO-' || LPAD(nextval('helpdesk.caso_numero_seq')::TEXT, 4, '0')),
  titulo VARCHAR(300) NOT NULL,
  descripcion TEXT,
  categoria_id INTEGER REFERENCES helpdesk.categorias_caso(id),
  recurso_id INTEGER REFERENCES helpdesk.recursos(id),
  cliente_id INTEGER REFERENCES generales.terceros(id),
  contacto_id INTEGER REFERENCES generales.contactos(id),
  tecnico_id INTEGER REFERENCES usuarios.usuarios(id),
  estado VARCHAR(20) DEFAULT 'Pendiente'
    CHECK (estado IN ('Pendiente', 'En Progreso', 'Completado', 'Cancelado')),
  telegram_chat_id VARCHAR(100),
  telegram_topic_id VARCHAR(100),
  whatsapp_chat_id VARCHAR(100),
  fuente VARCHAR(20) DEFAULT 'Manual'
    CHECK (fuente IN ('Manual', 'WhatsApp', 'Telegram', 'Email', 'Web')),
  ai_report TEXT,
  solucion TEXT,
  venta_item_id INTEGER REFERENCES facturacion.ventas_items(id),
  resumen TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_casos_updated_at ON helpdesk.casos;
CREATE TRIGGER trg_casos_updated_at
  BEFORE UPDATE ON helpdesk.casos
  FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

-- ------------------------------------------------------------------
-- 4. CASOS_CONTACTOS (relación muchos-a-muchos)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS helpdesk.casos_contactos (
  caso_id INTEGER NOT NULL REFERENCES helpdesk.casos(id) ON DELETE CASCADE,
  contacto_id INTEGER NOT NULL REFERENCES generales.contactos(id) ON DELETE CASCADE,
  PRIMARY KEY (caso_id, contacto_id)
);

-- ------------------------------------------------------------------
-- 5. CASO_DETALLES (bitácora del caso)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS helpdesk.caso_detalles (
  id SERIAL PRIMARY KEY,
  caso_id INTEGER NOT NULL REFERENCES helpdesk.casos(id) ON DELETE CASCADE,
  creado_por INTEGER REFERENCES usuarios.usuarios(id),
  contenido TEXT NOT NULL,
  tipo VARCHAR(20) DEFAULT 'Comentario'
    CHECK (tipo IN ('Comentario', 'Diagnóstico', 'Solución', 'Acuerdo', 'Sistema')),
  created_at TIMESTAMPTZ DEFAULT now()
);


ALTER TABLE generales.terceros ADD COLUMN es_cliente BOOLEAN DEFAULT FALSE;
ALTER TABLE generales.terceros ADD COLUMN es_proveedor BOOLEAN DEFAULT FALSE;

-- Backfill: terceros que aparecen como receptor en ventas son clientes
UPDATE generales.terceros SET es_cliente = TRUE
WHERE id IN (SELECT DISTINCT receptor_id FROM facturacion.ventas);

-- Backfill: terceros que aparecen como emisor/proveedor en ventas/compras son proveedores
UPDATE generales.terceros SET es_proveedor = TRUE
WHERE id IN (SELECT DISTINCT emisor_id FROM facturacion.ventas)
   OR id IN (SELECT DISTINCT proveedor_id FROM compras.facturas_compra);

-- Cliente por defecto para ventas sin factura (el flujo de venta no crea terceros)
INSERT INTO generales.terceros (tipo_documento, numero_documento, razon_social, es_cliente)
VALUES ('13', '123456789', 'Ventas sin factura', true)
ON CONFLICT (tipo_documento, numero_documento)
DO UPDATE SET
  razon_social = EXCLUDED.razon_social,
  es_cliente = true,
  updated_at = now();


-- Tabla maestra de tipos de recurso
CREATE TABLE IF NOT EXISTS helpdesk.tipos_recurso (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(50) NOT NULL UNIQUE,
    created_at  TIMESTAMP DEFAULT now()
);

INSERT INTO helpdesk.tipos_recurso (nombre) VALUES
    ('Computador'),
    ('Hosting'),
    ('Office 365'),
    ('Red'),
    ('Celular'),
    ('Impresora'),
    ('Servidor'),
    ('UPS'),
    ('Cámara'),
    ('Otro')
ON CONFLICT (nombre) DO NOTHING;

-- Migrar constraint CHECK a FK
ALTER TABLE helpdesk.recursos DROP CONSTRAINT IF EXISTS helpdesk_recursos_tipo_check;
ALTER TABLE helpdesk.recursos DROP CONSTRAINT IF EXISTS recursos_tipo_check;
ALTER TABLE helpdesk.recursos DROP CONSTRAINT IF EXISTS fk_recurso_tipo;

ALTER TABLE helpdesk.recursos
    ADD CONSTRAINT fk_recurso_tipo
    FOREIGN KEY (tipo)
    REFERENCES helpdesk.tipos_recurso(nombre)
    ON DELETE RESTRICT;


-- Migration 21: Many-to-many entre casos y recursos
-- Permite vincular uno o varios recursos a un caso de soporte

CREATE TABLE IF NOT EXISTS helpdesk.casos_recursos (
  caso_id INTEGER NOT NULL REFERENCES helpdesk.casos(id) ON DELETE CASCADE,
  recurso_id INTEGER NOT NULL REFERENCES helpdesk.recursos(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (caso_id, recurso_id)
);

-- Migrar recurso_id existente de helpdesk.casos a la nueva tabla pivote
INSERT INTO helpdesk.casos_recursos (caso_id, recurso_id)
SELECT id, recurso_id FROM helpdesk.casos WHERE recurso_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- Nota: la columna recurso_id en helpdesk.casos se mantiene por compatibilidad
-- pero ya no se usa para nuevos registros. En el futuro se puede eliminar.

