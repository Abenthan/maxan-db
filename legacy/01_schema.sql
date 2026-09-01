-- =====================================================================
-- ESQUEMA DE BASE DE DATOS: SISTEMA DE FACTURAS ELECTRÓNICAS DIAN
-- PostgreSQL 14+
-- Diseñado a partir de la estructura UBL 2.1 / DIAN 2.1
-- (AttachedDocument + Invoice + ApplicationResponse)
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS facturacion;
SET search_path TO facturacion;

-- ---------------------------------------------------------------------
-- 1. TERCEROS (emisores y receptores: clientes, proveedores, tú mismo)
-- ---------------------------------------------------------------------
CREATE TABLE terceros (
    id                  SERIAL PRIMARY KEY,
    tipo_documento      VARCHAR(5)   NOT NULL,        -- schemeID DIAN: 13=NIT, 31=NIT jurídico, etc.
    numero_documento    VARCHAR(20)  NOT NULL,
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
    emisor_id                   INT NOT NULL REFERENCES terceros(id),
    receptor_id                 INT NOT NULL REFERENCES terceros(id),

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
    BEFORE UPDATE ON terceros
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
JOIN terceros e ON e.id = f.emisor_id
JOIN terceros r ON r.id = f.receptor_id;
