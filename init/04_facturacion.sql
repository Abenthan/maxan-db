-- ============================================================
-- maxan-db - 04_facturacion.sql (generado por tools/build_init.ps1)
-- Objetos locales del schema 'facturacion': tablas, secuencias,
-- defaults, constraints locales, indices, triggers y FKs locales.
-- Las FKs que apuntan a otro schema viven en 99_fk_cross.sql
-- y las vistas en 90_vistas.sql.
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
CREATE SCHEMA IF NOT EXISTS facturacion;

CREATE TABLE facturacion.ventas (
    id integer NOT NULL,
    cufe character varying(100),
    prefijo character varying(10),
    numero character varying(20),
    numero_completo character varying(30) NOT NULL,
    tipo_documento_code character varying(5),
    customization_id character varying(10),
    fecha_emision date NOT NULL,
    hora_emision time without time zone,
    fecha_vencimiento date,
    moneda character varying(3) DEFAULT 'COP'::character varying,
    valor_subtotal numeric(18,2) DEFAULT 0,
    valor_descuento numeric(18,2) DEFAULT 0,
    valor_recargo numeric(18,2) DEFAULT 0,
    valor_total_bruto numeric(18,2) DEFAULT 0,
    valor_total_impuestos numeric(18,2) DEFAULT 0,
    valor_iva numeric(18,2) DEFAULT 0,
    valor_inc numeric(18,2) DEFAULT 0,
    valor_ica numeric(18,2) DEFAULT 0,
    valor_total_neto numeric(18,2) DEFAULT 0,
    valor_retencion_fuente numeric(18,2) DEFAULT 0,
    valor_retencion_iva numeric(18,2) DEFAULT 0,
    valor_retencion_ica numeric(18,2) DEFAULT 0,
    valor_anticipos numeric(18,2) DEFAULT 0,
    valor_a_pagar numeric(18,2) NOT NULL,
    emisor_id integer NOT NULL,
    receptor_id integer NOT NULL,
    resolucion_numero character varying(50),
    resolucion_fecha_desde date,
    resolucion_fecha_hasta date,
    resolucion_prefijo character varying(10),
    resolucion_rango_desde character varying(20),
    resolucion_rango_hasta character varying(20),
    medio_pago_code character varying(10),
    fecha_vencimiento_pago date,
    periodo_facturacion character varying(255),
    qr_code text,
    codigo_respuesta_dian character varying(10),
    descripcion_respuesta_dian character varying(255),
    estado_validacion_dian character varying(10),
    fecha_validacion_dian date,
    hora_validacion_dian time without time zone,
    estado character varying(20) DEFAULT 'recibida'::character varying,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    saldo_pendiente numeric(18,2),
    observaciones text,
    CONSTRAINT ventas_estado_check CHECK (((estado)::text = ANY (ARRAY[('recibida'::character varying)::text, ('pendiente_pago'::character varying)::text, ('pagada_parcial'::character varying)::text, ('pagada'::character varying)::text, ('anulada'::character varying)::text, ('rechazada'::character varying)::text])))
);
CREATE TABLE facturacion.factura_archivos (
    id integer NOT NULL,
    factura_id integer NOT NULL,
    tipo_archivo character varying(20) NOT NULL,
    nombre_archivo character varying(255),
    ruta_archivo character varying(500),
    contenido_xml text,
    hash_sha256 character varying(64),
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT factura_archivos_tipo_archivo_check CHECK (((tipo_archivo)::text = ANY (ARRAY[('xml_attached_document'::character varying)::text, ('xml_invoice'::character varying)::text, ('xml_application_response'::character varying)::text, ('pdf'::character varying)::text, ('otro'::character varying)::text])))
);
CREATE SEQUENCE facturacion.factura_archivos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE facturacion.factura_archivos_id_seq OWNED BY facturacion.factura_archivos.id;
CREATE TABLE facturacion.factura_impuestos (
    id integer NOT NULL,
    factura_id integer NOT NULL,
    factura_item_id integer,
    tipo_impuesto character varying(10) NOT NULL,
    nombre_impuesto character varying(50),
    porcentaje numeric(5,2) DEFAULT 0,
    base_gravable numeric(18,2) DEFAULT 0,
    valor numeric(18,2) DEFAULT 0
);
CREATE SEQUENCE facturacion.factura_impuestos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE facturacion.factura_impuestos_id_seq OWNED BY facturacion.factura_impuestos.id;
CREATE TABLE facturacion.factura_respuestas_dian (
    id integer NOT NULL,
    factura_id integer NOT NULL,
    linea_id integer,
    codigo_respuesta character varying(10),
    descripcion text
);
CREATE SEQUENCE facturacion.factura_respuestas_dian_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE facturacion.factura_respuestas_dian_id_seq OWNED BY facturacion.factura_respuestas_dian.id;
CREATE SEQUENCE facturacion.ventas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE facturacion.ventas_id_seq OWNED BY facturacion.ventas.id;
CREATE TABLE facturacion.ventas_items (
    id integer NOT NULL,
    venta_id integer NOT NULL,
    numero_linea integer NOT NULL,
    descripcion text NOT NULL,
    codigo_producto character varying(50),
    cantidad numeric(18,6) DEFAULT 1 NOT NULL,
    unidad_medida character varying(10),
    valor_unitario numeric(18,2) NOT NULL,
    porcentaje_descuento numeric(5,2) DEFAULT 0,
    valor_descuento numeric(18,2) DEFAULT 0,
    valor_linea numeric(18,2) NOT NULL,
    producto_id integer,
    valor_retencion_fuente numeric(18,2) DEFAULT 0 NOT NULL
);
CREATE SEQUENCE facturacion.ventas_items_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE facturacion.ventas_items_id_seq OWNED BY facturacion.ventas_items.id;
CREATE SEQUENCE facturacion.ventas_manual_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER TABLE ONLY facturacion.factura_archivos ALTER COLUMN id SET DEFAULT nextval('facturacion.factura_archivos_id_seq'::regclass);
ALTER TABLE ONLY facturacion.factura_impuestos ALTER COLUMN id SET DEFAULT nextval('facturacion.factura_impuestos_id_seq'::regclass);
ALTER TABLE ONLY facturacion.factura_respuestas_dian ALTER COLUMN id SET DEFAULT nextval('facturacion.factura_respuestas_dian_id_seq'::regclass);
ALTER TABLE ONLY facturacion.ventas ALTER COLUMN id SET DEFAULT nextval('facturacion.ventas_id_seq'::regclass);
ALTER TABLE ONLY facturacion.ventas_items ALTER COLUMN id SET DEFAULT nextval('facturacion.ventas_items_id_seq'::regclass);
ALTER TABLE ONLY facturacion.factura_archivos
    ADD CONSTRAINT factura_archivos_pkey PRIMARY KEY (id);
ALTER TABLE ONLY facturacion.factura_impuestos
    ADD CONSTRAINT factura_impuestos_pkey PRIMARY KEY (id);
ALTER TABLE ONLY facturacion.ventas_items
    ADD CONSTRAINT factura_items_factura_id_numero_linea_key UNIQUE (venta_id, numero_linea);
ALTER TABLE ONLY facturacion.ventas_items
    ADD CONSTRAINT factura_items_pkey PRIMARY KEY (id);
ALTER TABLE ONLY facturacion.factura_respuestas_dian
    ADD CONSTRAINT factura_respuestas_dian_pkey PRIMARY KEY (id);
ALTER TABLE ONLY facturacion.ventas
    ADD CONSTRAINT facturas_cufe_key UNIQUE (cufe);
ALTER TABLE ONLY facturacion.ventas
    ADD CONSTRAINT facturas_pkey PRIMARY KEY (id);
CREATE INDEX idx_facturas_emisor ON facturacion.ventas USING btree (emisor_id);
CREATE INDEX idx_facturas_estado ON facturacion.ventas USING btree (estado);
CREATE INDEX idx_facturas_fecha ON facturacion.ventas USING btree (fecha_emision);
CREATE INDEX idx_facturas_receptor ON facturacion.ventas USING btree (receptor_id);
CREATE TRIGGER trg_facturas_updated_at BEFORE UPDATE ON facturacion.ventas FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();
ALTER TABLE ONLY facturacion.factura_archivos
    ADD CONSTRAINT factura_archivos_factura_id_fkey FOREIGN KEY (factura_id) REFERENCES facturacion.ventas(id) ON DELETE CASCADE;
ALTER TABLE ONLY facturacion.factura_impuestos
    ADD CONSTRAINT factura_impuestos_factura_id_fkey FOREIGN KEY (factura_id) REFERENCES facturacion.ventas(id) ON DELETE CASCADE;
ALTER TABLE ONLY facturacion.factura_impuestos
    ADD CONSTRAINT factura_impuestos_factura_item_id_fkey FOREIGN KEY (factura_item_id) REFERENCES facturacion.ventas_items(id) ON DELETE CASCADE;
ALTER TABLE ONLY facturacion.ventas_items
    ADD CONSTRAINT factura_items_factura_id_fkey FOREIGN KEY (venta_id) REFERENCES facturacion.ventas(id) ON DELETE CASCADE;
ALTER TABLE ONLY facturacion.factura_respuestas_dian
    ADD CONSTRAINT factura_respuestas_dian_factura_id_fkey FOREIGN KEY (factura_id) REFERENCES facturacion.ventas(id) ON DELETE CASCADE;
