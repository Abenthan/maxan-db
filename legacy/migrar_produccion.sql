-- ============================================================
-- CONSOLIDADO COMPLETO - Ejecutar en DBeaver contra producción
-- Crea todos los schemas, tablas, vistas, triggers y datos
-- Seguro para re-ejecución (todo con IF NOT EXISTS / OR REPLACE)
-- ============================================================

-- ============================================================
-- 1. SCHEMA FACTURACION
-- ============================================================
CREATE SCHEMA IF NOT EXISTS facturacion;

CREATE TABLE IF NOT EXISTS generales.terceros (
    id                  SERIAL PRIMARY KEY,
    tipo_documento      VARCHAR(5),
    numero_documento    VARCHAR(20),
    digito_verificacion VARCHAR(1),
    tipo_persona        VARCHAR(20),
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
    es_propio           BOOLEAN      DEFAULT FALSE,
    created_at          TIMESTAMP    DEFAULT now(),
    updated_at          TIMESTAMP    DEFAULT now(),
    UNIQUE (tipo_documento, numero_documento)
);

ALTER TABLE generales.terceros ADD COLUMN IF NOT EXISTS es_cliente BOOLEAN DEFAULT FALSE;
ALTER TABLE generales.terceros ADD COLUMN IF NOT EXISTS es_proveedor BOOLEAN DEFAULT FALSE;

CREATE TABLE IF NOT EXISTS facturacion.ventas (
    id                          SERIAL PRIMARY KEY,
    cufe                        VARCHAR(100) UNIQUE,
    prefijo                     VARCHAR(10),
    numero                      VARCHAR(20),
    numero_completo             VARCHAR(30)  NOT NULL,
    tipo_documento_code         VARCHAR(5),
    customization_id            VARCHAR(10),
    fecha_emision               DATE         NOT NULL,
    hora_emision                TIME,
    fecha_vencimiento           DATE,
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
    emisor_id                   INT NOT NULL REFERENCES generales.terceros(id),
    receptor_id                 INT NOT NULL REFERENCES generales.terceros(id),
    resolucion_numero           VARCHAR(50),
    resolucion_fecha_desde      DATE,
    resolucion_fecha_hasta      DATE,
    resolucion_prefijo          VARCHAR(10),
    resolucion_rango_desde      VARCHAR(20),
    resolucion_rango_hasta      VARCHAR(20),
    medio_pago_code             VARCHAR(10),
    fecha_vencimiento_pago      DATE,
    periodo_facturacion         VARCHAR(255),
    qr_code                     TEXT,
    codigo_respuesta_dian       VARCHAR(10),
    descripcion_respuesta_dian  VARCHAR(255),
    estado_validacion_dian      VARCHAR(10),
    fecha_validacion_dian       DATE,
    hora_validacion_dian        TIME,
    estado                      VARCHAR(20) DEFAULT 'recibida',
    created_at                  TIMESTAMP DEFAULT now(),
    updated_at                  TIMESTAMP DEFAULT now()
);

ALTER TABLE facturacion.ventas ADD COLUMN IF NOT EXISTS saldo_pendiente NUMERIC(18,2);
ALTER TABLE facturacion.ventas ADD COLUMN IF NOT EXISTS observaciones TEXT;

ALTER TABLE facturacion.ventas DROP CONSTRAINT IF EXISTS facturas_estado_check;
ALTER TABLE facturacion.ventas DROP CONSTRAINT IF EXISTS ventas_estado_check;
ALTER TABLE facturacion.ventas ADD CONSTRAINT ventas_estado_check
    CHECK (estado IN ('recibida','pendiente_pago','pagada_parcial','pagada','anulada','rechazada'));

ALTER TABLE facturacion.ventas ALTER COLUMN cufe DROP NOT NULL;

CREATE INDEX IF NOT EXISTS idx_ventas_emisor   ON facturacion.ventas(emisor_id);
CREATE INDEX IF NOT EXISTS idx_ventas_receptor ON facturacion.ventas(receptor_id);
CREATE INDEX IF NOT EXISTS idx_ventas_fecha    ON facturacion.ventas(fecha_emision);
CREATE INDEX IF NOT EXISTS idx_ventas_estado   ON facturacion.ventas(estado);

CREATE TABLE IF NOT EXISTS facturacion.ventas_items (
    id                   SERIAL PRIMARY KEY,
    venta_id             INT NOT NULL REFERENCES facturacion.ventas(id) ON DELETE CASCADE,
    numero_linea         INT NOT NULL,
    descripcion          TEXT NOT NULL,
    codigo_producto      VARCHAR(50),
    cantidad             NUMERIC(18,6) NOT NULL DEFAULT 1,
    unidad_medida        VARCHAR(10),
    valor_unitario       NUMERIC(18,2) NOT NULL,
    porcentaje_descuento NUMERIC(5,2) DEFAULT 0,
    valor_descuento      NUMERIC(18,2) DEFAULT 0,
    valor_linea          NUMERIC(18,2) NOT NULL,
    UNIQUE (venta_id, numero_linea)
);

ALTER TABLE facturacion.ventas_items ADD COLUMN IF NOT EXISTS producto_id INT REFERENCES inventario.productos(id);
ALTER TABLE facturacion.ventas_items ADD COLUMN IF NOT EXISTS valor_retencion_fuente NUMERIC(18,2) NOT NULL DEFAULT 0;

CREATE TABLE IF NOT EXISTS facturacion.factura_impuestos (
    id               SERIAL PRIMARY KEY,
    venta_id         INT NOT NULL REFERENCES facturacion.ventas(id) ON DELETE CASCADE,
    venta_item_id    INT REFERENCES facturacion.ventas_items(id) ON DELETE CASCADE,
    tipo_impuesto    VARCHAR(10) NOT NULL,
    nombre_impuesto  VARCHAR(50),
    porcentaje       NUMERIC(5,2) DEFAULT 0,
    base_gravable    NUMERIC(18,2) DEFAULT 0,
    valor            NUMERIC(18,2) DEFAULT 0
);

CREATE TABLE IF NOT EXISTS facturacion.factura_respuestas_dian (
    id              SERIAL PRIMARY KEY,
    venta_id        INT NOT NULL REFERENCES facturacion.ventas(id) ON DELETE CASCADE,
    linea_id        INT,
    codigo_respuesta VARCHAR(10),
    descripcion      TEXT
);

CREATE TABLE IF NOT EXISTS facturacion.factura_archivos (
    id              SERIAL PRIMARY KEY,
    venta_id        INT NOT NULL REFERENCES facturacion.ventas(id) ON DELETE CASCADE,
    tipo_archivo    VARCHAR(20) NOT NULL
                    CHECK (tipo_archivo IN ('xml_attached_document','xml_invoice','xml_application_response','pdf','otro')),
    nombre_archivo  VARCHAR(255),
    ruta_archivo    VARCHAR(500),
    contenido_xml   TEXT,
    hash_sha256     VARCHAR(64),
    created_at      TIMESTAMP DEFAULT now()
);

CREATE OR REPLACE FUNCTION facturacion.fn_set_updated_at()
RETURNS TRIGGER AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_ventas_updated_at ON facturacion.ventas;
CREATE TRIGGER trg_ventas_updated_at
    BEFORE UPDATE ON facturacion.ventas
    FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

DROP TRIGGER IF EXISTS trg_terceros_updated_at ON generales.terceros;
CREATE TRIGGER trg_terceros_updated_at
    BEFORE UPDATE ON generales.terceros
    FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

CREATE SEQUENCE IF NOT EXISTS facturacion.ventas_manual_seq START 1;

-- Las vistas vw_facturas_resumen, vw_utilidad_items y vw_utilidad_productos
-- se definen al final del script, después de todas las tablas.

-- ============================================================
-- 2. SCHEMA COMPRAS
-- ============================================================
CREATE SCHEMA IF NOT EXISTS compras;

CREATE TABLE IF NOT EXISTS compras.facturas_compra (
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
    valor_a_pagar           NUMERIC(18,2) NOT NULL,
    proveedor_id            INT NOT NULL REFERENCES generales.terceros(id),
    receptor_id             INT NOT NULL REFERENCES generales.terceros(id),
    estado                  VARCHAR(20) DEFAULT 'recibida'
                             CHECK (estado IN ('recibida','pendiente_pago','pagada_parcial','pagada','anulada','rechazada')),
    created_at              TIMESTAMP DEFAULT now(),
    updated_at              TIMESTAMP DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_facturas_compra_updated_at ON compras.facturas_compra;
CREATE TRIGGER trg_facturas_compra_updated_at
    BEFORE UPDATE ON compras.facturas_compra
    FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

CREATE TABLE IF NOT EXISTS compras.facturas_compra_archivos (
    id                  SERIAL PRIMARY KEY,
    factura_compra_id   INT NOT NULL REFERENCES compras.facturas_compra(id) ON DELETE CASCADE,
    tipo_archivo        VARCHAR(20) NOT NULL
                         CHECK (tipo_archivo IN ('xml_invoice','pdf','otro')),
    nombre_archivo      VARCHAR(255),
    ruta_archivo        VARCHAR(500),
    contenido_xml       TEXT,
    hash_sha256          VARCHAR(64),
    created_at           TIMESTAMP DEFAULT now()
);

-- ============================================================
-- 3. SCHEMA GASTOS
-- ============================================================
CREATE SCHEMA IF NOT EXISTS gastos;

CREATE TABLE IF NOT EXISTS gastos.clasificaciones (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(50) NOT NULL UNIQUE,
    created_at  TIMESTAMP DEFAULT now()
);

INSERT INTO gastos.clasificaciones (nombre) VALUES
    ('Suministros'), ('Operacional'), ('Administrativo')
ON CONFLICT (nombre) DO NOTHING;

CREATE TABLE IF NOT EXISTS gastos.gastos (
    id                  SERIAL PRIMARY KEY,
    factura_compra_id   INT REFERENCES compras.facturas_compra(id) ON DELETE CASCADE,
    proveedor_id        INT REFERENCES generales.terceros(id),
    producto_id         INT REFERENCES inventario.productos(id),
    venta_item_id        INT REFERENCES facturacion.ventas_items(id),
    descripcion          TEXT NOT NULL,
    clasificacion         VARCHAR(20) NOT NULL,
    cantidad              NUMERIC(18,6) NOT NULL DEFAULT 1,
    valor_unitario         NUMERIC(18,2) NOT NULL,
    valor_total            NUMERIC(18,2) NOT NULL,
    fecha                  DATE NOT NULL DEFAULT CURRENT_DATE,
    created_at             TIMESTAMP DEFAULT now(),
    updated_at             TIMESTAMP DEFAULT now(),
    CHECK (NOT (producto_id IS NOT NULL AND venta_item_id IS NOT NULL))
);

ALTER TABLE gastos.gastos ADD COLUMN IF NOT EXISTS codigo_producto VARCHAR(50);

ALTER TABLE gastos.gastos DROP CONSTRAINT IF EXISTS gastos_clasificacion_check;
ALTER TABLE gastos.gastos DROP CONSTRAINT IF EXISTS gastos_gastos_clasificacion_check;
ALTER TABLE gastos.gastos DROP CONSTRAINT IF EXISTS fk_gasto_clasificacion;
ALTER TABLE gastos.gastos ADD CONSTRAINT fk_gasto_clasificacion
    FOREIGN KEY (clasificacion) REFERENCES gastos.clasificaciones(nombre);

CREATE INDEX IF NOT EXISTS idx_gastos_factura_compra ON gastos.gastos(factura_compra_id);
CREATE INDEX IF NOT EXISTS idx_gastos_producto       ON gastos.gastos(producto_id);
CREATE INDEX IF NOT EXISTS idx_gastos_venta_item     ON gastos.gastos(venta_item_id);

DROP TRIGGER IF EXISTS trg_gastos_updated_at ON gastos.gastos;
CREATE TRIGGER trg_gastos_updated_at
    BEFORE UPDATE ON gastos.gastos
    FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

CREATE OR REPLACE FUNCTION gastos.fn_set_clasificacion()
RETURNS TRIGGER AS $$
BEGIN
    IF NEW.producto_id IS NOT NULL THEN
        NEW.clasificacion := 'Suministros';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_gastos_set_clasificacion ON gastos.gastos;
CREATE TRIGGER trg_gastos_set_clasificacion
    BEFORE INSERT OR UPDATE ON gastos.gastos
    FOR EACH ROW EXECUTE FUNCTION gastos.fn_set_clasificacion();

-- ============================================================
-- 4. SCHEMA INVENTARIO
-- ============================================================
CREATE SCHEMA IF NOT EXISTS inventario;

CREATE TABLE IF NOT EXISTS inventario.productos (
    id              SERIAL PRIMARY KEY,
    codigo          VARCHAR(50) NOT NULL UNIQUE,
    nombre          VARCHAR(255) NOT NULL,
    categoria       VARCHAR(100),
    inventariable   BOOLEAN NOT NULL DEFAULT TRUE,
    unidad_medida   VARCHAR(10) DEFAULT 'UND',
    created_at      TIMESTAMP DEFAULT now(),
    updated_at      TIMESTAMP DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_productos_updated_at ON inventario.productos;
CREATE TRIGGER trg_productos_updated_at
    BEFORE UPDATE ON inventario.productos
    FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

CREATE TABLE IF NOT EXISTS inventario.categorias (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL UNIQUE,
    created_at  TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS inventario.entradas (
    id                  SERIAL PRIMARY KEY,
    gasto_id            INT NOT NULL REFERENCES gastos.gastos(id) ON DELETE CASCADE,
    producto_id         INT NOT NULL REFERENCES inventario.productos(id),
    cantidad            NUMERIC(18,6) NOT NULL,
    cantidad_disponible NUMERIC(18,6) NOT NULL,
    costo_unitario      NUMERIC(18,2) NOT NULL,
    fecha               DATE NOT NULL,
    created_at          TIMESTAMP DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_entradas_producto_fecha ON inventario.entradas(producto_id, fecha, id);

CREATE TABLE IF NOT EXISTS inventario.salidas (
    id               SERIAL PRIMARY KEY,
    factura_item_id  INT NOT NULL REFERENCES facturacion.ventas_items(id) ON DELETE CASCADE,
    producto_id      INT NOT NULL REFERENCES inventario.productos(id),
    cantidad          NUMERIC(18,6) NOT NULL,
    costo_total        NUMERIC(18,2) NOT NULL,
    created_at         TIMESTAMP DEFAULT now()
);

CREATE TABLE IF NOT EXISTS inventario.salida_detalle (
    id                  SERIAL PRIMARY KEY,
    salida_id           INT NOT NULL REFERENCES inventario.salidas(id) ON DELETE CASCADE,
    entrada_id           INT NOT NULL REFERENCES inventario.entradas(id),
    cantidad_consumida    NUMERIC(18,6) NOT NULL,
    costo_unitario         NUMERIC(18,2) NOT NULL
);

CREATE OR REPLACE VIEW inventario.vw_stock_disponible AS
SELECT p.id AS producto_id, p.nombre, p.categoria,
    COALESCE(SUM(e.cantidad_disponible), 0) AS stock_actual
FROM inventario.productos p
LEFT JOIN inventario.entradas e ON e.producto_id = p.id
WHERE p.inventariable = TRUE
GROUP BY p.id, p.nombre, p.categoria;

-- El trigger fn_crear_entrada se define aquí, después que gastos e inventario existen
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
                SET producto_id = NEW.producto_id, cantidad = NEW.cantidad,
                    cantidad_disponible = NEW.cantidad, costo_unitario = NEW.valor_unitario, fecha = NEW.fecha
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

-- ============================================================
-- 5. SCHEMA CARTERA
-- ============================================================
CREATE SCHEMA IF NOT EXISTS cartera;

CREATE TABLE IF NOT EXISTS cartera.medios_pago (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(100) NOT NULL UNIQUE,
    created_at  TIMESTAMP DEFAULT now()
);

INSERT INTO cartera.medios_pago (nombre) VALUES
    ('Efectivo'), ('Transferencia Bancaria'), ('Cheque'),
    ('Tarjeta Débito'), ('Tarjeta Crédito'), ('Consignación'), ('Datafono')
ON CONFLICT (nombre) DO NOTHING;

CREATE TABLE IF NOT EXISTS cartera.pagos (
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

CREATE INDEX IF NOT EXISTS idx_pagos_cliente ON cartera.pagos(cliente_id);
CREATE INDEX IF NOT EXISTS idx_pagos_fecha   ON cartera.pagos(fecha_pago);

DROP TRIGGER IF EXISTS trg_pagos_updated_at ON cartera.pagos;
CREATE TRIGGER trg_pagos_updated_at
    BEFORE UPDATE ON cartera.pagos
    FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

CREATE TABLE IF NOT EXISTS cartera.pago_aplicaciones (
    id              SERIAL PRIMARY KEY,
    pago_id         INT NOT NULL REFERENCES cartera.pagos(id) ON DELETE CASCADE,
    venta_id        INT NOT NULL REFERENCES facturacion.ventas(id) ON DELETE CASCADE,
    valor_aplicado  NUMERIC(18,2) NOT NULL CHECK (valor_aplicado > 0),
    created_at      TIMESTAMP DEFAULT now(),
    UNIQUE (pago_id, venta_id)
);

CREATE INDEX IF NOT EXISTS idx_pago_aplicaciones_pago   ON cartera.pago_aplicaciones(pago_id);
CREATE INDEX IF NOT EXISTS idx_pago_aplicaciones_venta  ON cartera.pago_aplicaciones(venta_id);

UPDATE facturacion.ventas SET saldo_pendiente = valor_a_pagar
WHERE saldo_pendiente IS NULL AND estado NOT IN ('anulada', 'rechazada');

UPDATE facturacion.ventas SET estado = 'pendiente_pago'
WHERE estado = 'recibida' AND saldo_pendiente > 0;

CREATE OR REPLACE FUNCTION cartera.fn_actualizar_saldo()
RETURNS TRIGGER AS $$
DECLARE
    v_total_pagado      NUMERIC(18,2);
    v_valor_venta       NUMERIC(18,2);
    v_total_retenciones NUMERIC(18,2);
    v_venta_id          INT;
BEGIN
    v_venta_id := COALESCE(NEW.venta_id, OLD.venta_id);
    SELECT v.valor_a_pagar INTO v_valor_venta FROM facturacion.ventas v WHERE v.id = v_venta_id;
    SELECT COALESCE(SUM(pa.valor_aplicado), 0) INTO v_total_pagado FROM cartera.pago_aplicaciones pa WHERE pa.venta_id = v_venta_id;
    SELECT COALESCE(v.valor_retencion_fuente, 0) INTO v_total_retenciones FROM facturacion.ventas v WHERE v.id = v_venta_id;
    UPDATE facturacion.ventas
    SET saldo_pendiente = GREATEST(v_valor_venta - v_total_pagado - v_total_retenciones, 0),
        estado = CASE
            WHEN v_total_pagado + v_total_retenciones >= v_valor_venta THEN 'pagada'
            WHEN v_total_pagado > 0 THEN 'pagada_parcial'
            ELSE 'pendiente_pago'
        END
    WHERE id = v_venta_id AND estado NOT IN ('anulada', 'rechazada');
    RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_pago_aplicaciones_actualizar_saldo ON cartera.pago_aplicaciones;
CREATE TRIGGER trg_pago_aplicaciones_actualizar_saldo
    AFTER INSERT OR DELETE ON cartera.pago_aplicaciones
    FOR EACH ROW EXECUTE FUNCTION cartera.fn_actualizar_saldo();

CREATE OR REPLACE VIEW cartera.vw_cartera_activa AS
SELECT v.id AS venta_id, v.numero_completo, v.fecha_emision, v.fecha_vencimiento,
    v.fecha_vencimiento_pago, v.valor_a_pagar, v.valor_retencion_fuente,
    v.valor_a_pagar - COALESCE(v.saldo_pendiente, 0) AS total_pagado,
    COALESCE(v.saldo_pendiente, v.valor_a_pagar) AS saldo_pendiente,
    t.id AS cliente_id, t.razon_social AS cliente, t.numero_documento AS nit_cliente,
    v.estado,
    CASE WHEN COALESCE(v.saldo_pendiente, v.valor_a_pagar) <= 0 THEN 'Pagada'
         WHEN v.fecha_vencimiento_pago IS NULL THEN 'Sin vencimiento'
         WHEN CURRENT_DATE > v.fecha_vencimiento_pago THEN 'Vencida'
         ELSE 'Al día' END AS estado_cartera,
    CASE WHEN COALESCE(v.saldo_pendiente, v.valor_a_pagar) <= 0 THEN 0
         WHEN v.fecha_vencimiento_pago IS NULL THEN 0
         WHEN CURRENT_DATE <= v.fecha_vencimiento_pago THEN 0
         WHEN (CURRENT_DATE - v.fecha_vencimiento_pago) <= 30 THEN 30
         WHEN (CURRENT_DATE - v.fecha_vencimiento_pago) <= 60 THEN 60
         WHEN (CURRENT_DATE - v.fecha_vencimiento_pago) <= 90 THEN 90
         ELSE 999 END AS dias_vencida
FROM facturacion.ventas v
JOIN generales.terceros t ON t.id = v.receptor_id
WHERE v.estado NOT IN ('anulada', 'rechazada')
ORDER BY v.fecha_vencimiento_pago NULLS LAST, v.fecha_emision DESC;

CREATE OR REPLACE VIEW cartera.vw_pagos_resumen AS
SELECT p.id, p.fecha_pago, p.valor_total, p.referencia, p.anulado,
    mp.nombre AS medio_pago, t.id AS cliente_id, t.razon_social AS cliente,
    t.numero_documento AS nit_cliente,
    COALESCE(pa.facturas_aplicadas, 0) AS facturas_aplicadas,
    COALESCE(pa.total_aplicado, 0) AS total_aplicado,
    CASE WHEN COALESCE(pa.total_aplicado, 0) < p.valor_total THEN p.valor_total - COALESCE(pa.total_aplicado, 0) ELSE 0 END AS sin_aplicar
FROM cartera.pagos p
JOIN generales.terceros t ON t.id = p.cliente_id
LEFT JOIN cartera.medios_pago mp ON mp.id = p.medio_pago_id
LEFT JOIN (SELECT pago_id, COUNT(*) AS facturas_aplicadas, SUM(valor_aplicado) AS total_aplicado FROM cartera.pago_aplicaciones GROUP BY pago_id) pa ON pa.pago_id = p.id
ORDER BY p.fecha_pago DESC, p.id DESC;

CREATE OR REPLACE VIEW cartera.vw_pago_detalle AS
SELECT pa.id AS aplicacion_id, pa.pago_id, pa.venta_id, pa.valor_aplicado,
    pa.created_at AS fecha_aplicacion, v.numero_completo AS factura_numero,
    v.fecha_emision AS factura_fecha, v.valor_a_pagar AS factura_valor
FROM cartera.pago_aplicaciones pa
JOIN facturacion.ventas v ON v.id = pa.venta_id;

-- ============================================================
-- 6. SCHEMA USUARIOS
-- ============================================================
CREATE SCHEMA IF NOT EXISTS usuarios;

CREATE TABLE IF NOT EXISTS usuarios.empresas (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL,
  nit VARCHAR(50) UNIQUE NOT NULL,
  activa BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_empresas_updated_at ON usuarios.empresas;
CREATE TRIGGER trg_empresas_updated_at
  BEFORE UPDATE ON usuarios.empresas
  FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

CREATE TABLE IF NOT EXISTS usuarios.usuarios (
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

DROP TRIGGER IF EXISTS trg_usuarios_updated_at ON usuarios.usuarios;
CREATE TRIGGER trg_usuarios_updated_at
  BEFORE UPDATE ON usuarios.usuarios
  FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

CREATE TABLE IF NOT EXISTS usuarios.roles (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(100) UNIQUE NOT NULL,
  descripcion TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS usuarios.permisos (
  id SERIAL PRIMARY KEY,
  codigo VARCHAR(100) UNIQUE NOT NULL,
  nombre VARCHAR(255) NOT NULL,
  descripcion TEXT,
  modulo VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS usuarios.roles_permisos (
  rol_id INTEGER NOT NULL REFERENCES usuarios.roles(id) ON DELETE CASCADE,
  permiso_id INTEGER NOT NULL REFERENCES usuarios.permisos(id) ON DELETE CASCADE,
  PRIMARY KEY (rol_id, permiso_id)
);

CREATE TABLE IF NOT EXISTS usuarios.usuarios_roles (
  usuario_id INTEGER NOT NULL REFERENCES usuarios.usuarios(id) ON DELETE CASCADE,
  rol_id INTEGER NOT NULL REFERENCES usuarios.roles(id) ON DELETE CASCADE,
  PRIMARY KEY (usuario_id, rol_id)
);

-- ============================================================
-- 7. SCHEMA HELPDESK
-- ============================================================
CREATE SCHEMA IF NOT EXISTS helpdesk;

CREATE TABLE IF NOT EXISTS helpdesk.categorias_mantenimiento (
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
  ('Redes / Cableado', '#14B8A6')
ON CONFLICT (nombre) DO NOTHING;

CREATE TABLE IF NOT EXISTS helpdesk.recursos (
  id SERIAL PRIMARY KEY,
  cliente_id INTEGER NOT NULL REFERENCES generales.terceros(id),
  nombre VARCHAR(200) NOT NULL,
  tipo VARCHAR(50) NOT NULL DEFAULT 'Computador',
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

ALTER TABLE helpdesk.recursos ADD COLUMN IF NOT EXISTS atributos JSONB DEFAULT '{}';

DROP TRIGGER IF EXISTS trg_recursos_updated_at ON helpdesk.recursos;
CREATE TRIGGER trg_recursos_updated_at
  BEFORE UPDATE ON helpdesk.recursos
  FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

CREATE TABLE IF NOT EXISTS helpdesk.mantenimientos (
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

DROP TRIGGER IF EXISTS trg_mantenimientos_updated_at ON helpdesk.mantenimientos;
CREATE TRIGGER trg_mantenimientos_updated_at
  BEFORE UPDATE ON helpdesk.mantenimientos
  FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

CREATE TABLE IF NOT EXISTS helpdesk.mantenimiento_detalles (
  id SERIAL PRIMARY KEY,
  mantenimiento_id INTEGER NOT NULL REFERENCES helpdesk.mantenimientos(id) ON DELETE CASCADE,
  creado_por INTEGER REFERENCES usuarios.usuarios(id),
  contenido TEXT NOT NULL,
  tipo VARCHAR(20) DEFAULT 'Comentario'
    CHECK (tipo IN ('Comentario', 'Diagnóstico', 'Solución', 'Repuesto', 'Acuerdo')),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS helpdesk.categorias_caso (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL UNIQUE,
  color VARCHAR(7) DEFAULT '#6B7280',
  activo BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO helpdesk.categorias_caso (nombre, color) VALUES
  ('Soporte Técnico', '#3B82F6'), ('Falla / Error', '#EF4444'),
  ('Instalación', '#10B981'), ('Consulta', '#F59E0B'),
  ('Mantenimiento', '#8B5CF6'), ('Configuración', '#14B8A6'),
  ('Otro', '#6B7280')
ON CONFLICT (nombre) DO NOTHING;

CREATE SCHEMA IF NOT EXISTS generales;

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
  solucion TEXT,
  venta_item_id INTEGER REFERENCES facturacion.ventas_items(id),
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_casos_updated_at ON helpdesk.casos;
CREATE TRIGGER trg_casos_updated_at
  BEFORE UPDATE ON helpdesk.casos
  FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

CREATE TABLE IF NOT EXISTS helpdesk.casos_contactos (
  caso_id INTEGER NOT NULL REFERENCES helpdesk.casos(id) ON DELETE CASCADE,
  contacto_id INTEGER NOT NULL REFERENCES generales.contactos(id) ON DELETE CASCADE,
  PRIMARY KEY (caso_id, contacto_id)
);

CREATE TABLE IF NOT EXISTS helpdesk.caso_detalles (
  id SERIAL PRIMARY KEY,
  caso_id INTEGER NOT NULL REFERENCES helpdesk.casos(id) ON DELETE CASCADE,
  creado_por INTEGER REFERENCES usuarios.usuarios(id),
  contenido TEXT NOT NULL,
  tipo VARCHAR(20) DEFAULT 'Comentario'
    CHECK (tipo IN ('Comentario', 'Diagnóstico', 'Solución', 'Acuerdo', 'Sistema')),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE IF NOT EXISTS helpdesk.tipos_recurso (
    id          SERIAL PRIMARY KEY,
    nombre      VARCHAR(50) NOT NULL UNIQUE,
    created_at  TIMESTAMP DEFAULT now()
);

INSERT INTO helpdesk.tipos_recurso (nombre) VALUES
    ('Computador'), ('Hosting'), ('Office 365'), ('Red'),
    ('Celular'), ('Impresora'), ('Servidor'), ('UPS'), ('Cámara'), ('Otro')
ON CONFLICT (nombre) DO NOTHING;

ALTER TABLE helpdesk.recursos DROP CONSTRAINT IF EXISTS helpdesk_recursos_tipo_check;
ALTER TABLE helpdesk.recursos DROP CONSTRAINT IF EXISTS recursos_tipo_check;
ALTER TABLE helpdesk.recursos DROP CONSTRAINT IF EXISTS fk_recurso_tipo;
ALTER TABLE helpdesk.recursos ADD CONSTRAINT fk_recurso_tipo
    FOREIGN KEY (tipo) REFERENCES helpdesk.tipos_recurso(nombre) ON DELETE RESTRICT;

CREATE TABLE IF NOT EXISTS helpdesk.casos_recursos (
  caso_id INTEGER NOT NULL REFERENCES helpdesk.casos(id) ON DELETE CASCADE,
  recurso_id INTEGER NOT NULL REFERENCES helpdesk.recursos(id) ON DELETE CASCADE,
  created_at TIMESTAMPTZ DEFAULT now(),
  PRIMARY KEY (caso_id, recurso_id)
);

INSERT INTO helpdesk.casos_recursos (caso_id, recurso_id)
SELECT id, recurso_id FROM helpdesk.casos WHERE recurso_id IS NOT NULL
ON CONFLICT DO NOTHING;

-- ============================================================
-- 8. SEED: TERCEROS desde Notion
-- ============================================================
INSERT INTO generales.terceros (tipo_documento, numero_documento, razon_social) VALUES
  ('NI', '900000001', 'Gestión Calidad'),
  ('NI', '900000002', 'Transglobal de Carga'),
  ('NI', '900000003', 'Montacargas y Transportes'),
  ('NI', '900000004', 'Promatel'),
  ('NI', '900000005', 'Grupo Carpini'),
  ('NI', '900000006', 'Símbolo'),
  ('NI', '900000007', 'Bekko'),
  ('NI', '900000008', 'M2 Contable'),
  ('NI', '900000009', 'Ankaras'),
  ('NI', '900000010', 'Agregados Antioquia'),
  ('NI', '900000011', 'Tysi'),
  ('NI', '900000012', 'Serfletar'),
  ('NI', '900000013', 'Express Labels'),
  ('NI', '900000014', 'AMUC')
ON CONFLICT (tipo_documento, numero_documento) DO NOTHING;

-- ============================================================
-- 9. SEED: RECURSOS desde Notion
-- ============================================================
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
  INSERT INTO helpdesk.recursos (cliente_id, nombre, tipo, marca, modelo, serial, descripcion) VALUES
    (v_gestion_calidad, 'Lenovo Andres Cortez',   'Computador', 'Lenovo', 'IdeaPad 3 15IRH10', NULL, NULL),
    (v_gestion_calidad, 'Lenovo Subey Tatiana',   'Computador', 'Lenovo', 'IdeaPad Slim 3 15IRH10', 'PF68N6RS', NULL),
    (v_gestion_calidad, 'Lenovo Shirley',         'Computador', 'Lenovo', 'IdeaPad 3 15IIL05', 'PF28BJH4', NULL),
    (v_gestion_calidad, 'HP 14 - Leidy Rodriguez','Computador', 'HP',     'HP 14', NULL, NULL),
    (v_gestion_calidad, 'Lenovo Thinkbook Sergio','Computador', 'Lenovo','Thinkbook', 'LR0EYTBH', NULL),
    (v_gestion_calidad, 'Lenovo ideapad 3 - Cindy Betancur','Computador','Lenovo','IdeaPad 3','PF3TE30J', NULL),
    (v_gestion_calidad, 'Lenovo S145 - Yazmin',   'Computador', 'Lenovo', 'S145', 'PF32XNZ3', NULL),
    (v_gestion_calidad, 'Lenovo IdeaPad 3 - Subey','Computador','Lenovo','IdeaPad 3', 'PF369BYV', NULL),
    (v_transglobal, 'Veronica Gestion Calidad',   'Computador', NULL, NULL, NULL, NULL),
    (v_transglobal, 'PC08 - Seguridad',           'Computador', 'DELL', 'Vostro 3458', '20Z8VF2', NULL),
    (v_montacargas, 'PC15 - Logistica2',             'Computador', 'DELL', 'Vostro 14 3000', '3WC9RM3', NULL),
    (v_montacargas, 'PC18 - Logistica1',             'Computador', 'ASUS', 'VivoBook X409DA_M409DA','L9N0CV059128376', NULL),
    (v_montacargas, 'PC04 - Gerencia Administrativa','Computador', 'HP', NULL, 'CND31328D8', 'PC02 - Portatil HP - Johan'),
    (v_montacargas, 'HP Logistica4',                 'Computador', 'HP', '245 G9', '5CG4074Y5F', NULL),
    (v_montacargas, 'PC Logistica3',                 'Computador', 'HP', '245G10', '5CG438064', NULL),
    (v_montacargas, 'PC17 - Coordinador Mantenimiento','Computador','HP', NULL, '5CD2403831', 'PC17 - Portatil HP - Julian Vergara'),
    (v_montacargas, 'PC016 - Compras',               'Computador', NULL, NULL, '5CG21721CN', NULL),
    (v_promatel, 'PC Sodimac',          'Computador', NULL, NULL, NULL, 'CPU Facturación Home Center'),
    (v_promatel, 'Portátil HP (Cartera)','Computador','HP', '245 G8', '5CG1320LKW', NULL),
    (v_promatel, 'HP AIO Cartera',      'Computador', 'HP', 'AIO 22-DF0007LA', '8CC1190PNZ', NULL),
    (v_promatel, 'Tesorería PC',        'Computador', NULL, NULL, NULL, NULL),
    (v_promatel, 'Hosting Promatel',    'Hosting', NULL, NULL, NULL, 'Hosting página web'),
    (v_grupo_carpini, 'HP AIO AuxContable','Computador','HP', 'AIO 24-F013LA', '8CC92326S8', NULL),
    (v_grupo_carpini, 'Construcción 4',    'Computador',NULL, NULL, NULL, NULL),
    (v_grupo_carpini, 'Comercial 2',       'Computador',NULL, NULL, NULL, NULL),
    (v_grupo_carpini, 'Construcción 2',    'Computador',NULL, NULL, NULL, NULL),
    (v_simbolo, 'Access Point TP Link',   'Red', 'TP-Link', NULL, NULL, 'SSID: Simbolo 5G'),
    (v_simbolo, 'HP Juan Diego',          'Computador','HP', NULL, NULL, NULL),
    (v_simbolo, 'ASUS X543UA - Yuliana Rua','Computador','ASUS','X543UA', 'MAN0CX23J75443D', NULL),
    (v_simbolo, 'Computador 1',           'Computador',NULL, NULL, NULL, NULL),
    (v_simbolo, 'Asus JuanFdo',           'Computador','ASUS', NULL, 'L8N0LP01F492334', NULL),
    (v_simbolo, 'Acer A514',             'Computador','Acer', 'A514', NULL, NULL),
    (v_bekko, 'ASUS Vivobook 14', 'Computador', 'ASUS', 'Vivobook 14', 'M1N0CX023456012', NULL),
    (v_m2_contable, 'Office 365 personal', 'Office 365', NULL, NULL, NULL, 'Suscripción anual'),
    (v_ankaras, 'ASUS X415', 'Computador', 'ASUS', 'X415', 'R2N0CV09X683088', NULL)
  ON CONFLICT (serial) DO NOTHING;
END $$;

-- ============================================================
-- 10. VISTAS (después de todas las tablas)
-- ============================================================

CREATE OR REPLACE VIEW facturacion.vw_facturas_resumen AS
SELECT v.id, v.numero_completo, v.cufe, v.fecha_emision, v.fecha_vencimiento,
    e.razon_social AS emisor, e.numero_documento AS nit_emisor,
    r.razon_social AS receptor, r.numero_documento AS nit_receptor,
    v.valor_a_pagar, v.estado, v.codigo_respuesta_dian, v.estado_validacion_dian,
    v.observaciones
FROM facturacion.ventas v
JOIN generales.terceros e ON e.id = v.emisor_id
JOIN generales.terceros r ON r.id = v.receptor_id;

DROP VIEW IF EXISTS facturacion.vw_utilidad_items;
CREATE OR REPLACE VIEW facturacion.vw_utilidad_items AS
SELECT
    fi.id AS venta_item_id, fi.descripcion, fi.valor_linea, fi.producto_id,
    COALESCE(v.valor_retencion_fuente, 0) AS valor_retencion_fuente,
    COALESCE(sal.costo_inventario, 0) AS costo_inventario,
    COALESCE(gd.costo_directo, 0) AS costo_directo,
    fi.valor_linea - COALESCE(sal.costo_inventario, 0) - COALESCE(gd.costo_directo, 0) - COALESCE(v.valor_retencion_fuente, 0) AS utilidad
FROM facturacion.ventas_items fi
JOIN facturacion.ventas v ON v.id = fi.venta_id
LEFT JOIN (SELECT factura_item_id, SUM(costo_total) AS costo_inventario FROM inventario.salidas GROUP BY factura_item_id) sal ON sal.factura_item_id = fi.id
LEFT JOIN (SELECT venta_item_id, SUM(valor_total) AS costo_directo FROM gastos.gastos WHERE venta_item_id IS NOT NULL GROUP BY venta_item_id) gd ON gd.venta_item_id = fi.id;

CREATE OR REPLACE VIEW inventario.vw_utilidad_productos AS
SELECT
    p.id AS producto_id, p.codigo, p.nombre, p.categoria,
    COALESCE(compras.costo_adquisiciones, 0) AS costo_adquisiciones,
    COALESCE(ventas.ingreso_ventas, 0) AS ingreso_ventas,
    COALESCE(gastos_extra.otros_costos, 0) AS otros_costos,
    COALESCE(ventas.ingreso_ventas, 0) - COALESCE(compras.costo_adquisiciones, 0) - COALESCE(gastos_extra.otros_costos, 0) AS utilidad
FROM inventario.productos p
LEFT JOIN (SELECT e.producto_id, SUM(e.cantidad * e.costo_unitario) AS costo_adquisiciones FROM inventario.entradas e GROUP BY e.producto_id) compras ON compras.producto_id = p.id
LEFT JOIN (SELECT s.producto_id, SUM(vi.valor_linea) AS ingreso_ventas FROM inventario.salidas s JOIN facturacion.ventas_items vi ON vi.id = s.factura_item_id GROUP BY s.producto_id) ventas ON ventas.producto_id = p.id
LEFT JOIN (SELECT g.producto_id, SUM(g.valor_total) AS otros_costos FROM gastos.gastos g WHERE g.producto_id IS NOT NULL AND g.venta_item_id IS NULL AND g.clasificacion <> 'Suministros' GROUP BY g.producto_id) gastos_extra ON gastos_extra.producto_id = p.id
ORDER BY p.nombre;

-- ============================================================
-- 11. search_path
-- ============================================================
ALTER ROLE maxan_user SET search_path TO facturacion, compras, inventario, gastos, cartera, usuarios, generales, helpdesk, public;
