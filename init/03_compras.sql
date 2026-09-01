-- ============================================================
-- maxan-db - 03_compras.sql (generado por tools/build_init.ps1)
-- Objetos locales del schema 'compras': tablas, secuencias,
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
CREATE SCHEMA IF NOT EXISTS compras;

CREATE TABLE compras.facturas_compra (
    id integer NOT NULL,
    tipo_documento_compra character varying(20) DEFAULT 'factura_electronica'::character varying NOT NULL,
    codigo_unico_documento character varying(100),
    numero_completo character varying(30) NOT NULL,
    fecha_emision date NOT NULL,
    fecha_recepcion date DEFAULT CURRENT_DATE,
    moneda character varying(3) DEFAULT 'COP'::character varying,
    valor_subtotal numeric(18,2) DEFAULT 0,
    valor_total_impuestos numeric(18,2) DEFAULT 0,
    valor_iva numeric(18,2) DEFAULT 0,
    valor_a_pagar numeric(18,2) NOT NULL,
    proveedor_id integer NOT NULL,
    receptor_id integer NOT NULL,
    estado character varying(20) DEFAULT 'recibida'::character varying,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    CONSTRAINT facturas_compra_estado_check CHECK (((estado)::text = ANY (ARRAY[('recibida'::character varying)::text, ('pendiente_pago'::character varying)::text, ('pagada_parcial'::character varying)::text, ('pagada'::character varying)::text, ('anulada'::character varying)::text, ('rechazada'::character varying)::text]))),
    CONSTRAINT facturas_compra_tipo_documento_compra_check CHECK (((tipo_documento_compra)::text = ANY (ARRAY[('factura_electronica'::character varying)::text, ('documento_soporte'::character varying)::text])))
);
CREATE TABLE compras.facturas_compra_archivos (
    id integer NOT NULL,
    factura_compra_id integer NOT NULL,
    tipo_archivo character varying(20) NOT NULL,
    nombre_archivo character varying(255),
    ruta_archivo character varying(500),
    contenido_xml text,
    hash_sha256 character varying(64),
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT facturas_compra_archivos_tipo_archivo_check CHECK (((tipo_archivo)::text = ANY (ARRAY[('xml_invoice'::character varying)::text, ('pdf'::character varying)::text, ('otro'::character varying)::text])))
);
CREATE SEQUENCE compras.facturas_compra_archivos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE compras.facturas_compra_archivos_id_seq OWNED BY compras.facturas_compra_archivos.id;
CREATE SEQUENCE compras.facturas_compra_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE compras.facturas_compra_id_seq OWNED BY compras.facturas_compra.id;
ALTER TABLE ONLY compras.facturas_compra ALTER COLUMN id SET DEFAULT nextval('compras.facturas_compra_id_seq'::regclass);
ALTER TABLE ONLY compras.facturas_compra_archivos ALTER COLUMN id SET DEFAULT nextval('compras.facturas_compra_archivos_id_seq'::regclass);
ALTER TABLE ONLY compras.facturas_compra_archivos
    ADD CONSTRAINT facturas_compra_archivos_pkey PRIMARY KEY (id);
ALTER TABLE ONLY compras.facturas_compra
    ADD CONSTRAINT facturas_compra_codigo_unico_documento_key UNIQUE (codigo_unico_documento);
ALTER TABLE ONLY compras.facturas_compra
    ADD CONSTRAINT facturas_compra_pkey PRIMARY KEY (id);
CREATE TRIGGER trg_facturas_compra_updated_at BEFORE UPDATE ON compras.facturas_compra FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();
ALTER TABLE ONLY compras.facturas_compra_archivos
    ADD CONSTRAINT facturas_compra_archivos_factura_compra_id_fkey FOREIGN KEY (factura_compra_id) REFERENCES compras.facturas_compra(id) ON DELETE CASCADE;
