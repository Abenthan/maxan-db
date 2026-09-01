-- ============================================================
-- maxan-db - 02_generales.sql (generado por tools/build_init.ps1)
-- Objetos locales del schema 'generales': tablas, secuencias,
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
CREATE SCHEMA IF NOT EXISTS generales;

CREATE TABLE generales.terceros (
    id integer NOT NULL,
    tipo_documento character varying(5),
    numero_documento character varying(20),
    digito_verificacion character varying(1),
    tipo_persona character varying(20),
    razon_social character varying(255) NOT NULL,
    direccion character varying(255),
    codigo_ciudad character varying(10),
    ciudad character varying(100),
    codigo_departamento character varying(10),
    departamento character varying(100),
    codigo_postal character varying(10),
    pais character varying(2) DEFAULT 'CO'::character varying,
    telefono character varying(50),
    email character varying(150),
    es_propio boolean DEFAULT false,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    es_cliente boolean DEFAULT false,
    es_proveedor boolean DEFAULT false
);
CREATE TABLE generales.contactos (
    id integer NOT NULL,
    cliente_id integer,
    nombre character varying(200) NOT NULL,
    telefono character varying(50),
    email character varying(200),
    whatsapp character varying(50),
    cargo character varying(200),
    activo boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);
CREATE SEQUENCE generales.contactos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE generales.contactos_id_seq OWNED BY generales.contactos.id;
CREATE SEQUENCE generales.terceros_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE generales.terceros_id_seq OWNED BY generales.terceros.id;
ALTER TABLE ONLY generales.contactos ALTER COLUMN id SET DEFAULT nextval('generales.contactos_id_seq'::regclass);
ALTER TABLE ONLY generales.terceros ALTER COLUMN id SET DEFAULT nextval('generales.terceros_id_seq'::regclass);
ALTER TABLE ONLY generales.contactos
    ADD CONSTRAINT contactos_pkey PRIMARY KEY (id);
ALTER TABLE ONLY generales.terceros
    ADD CONSTRAINT terceros_documento_unique UNIQUE (tipo_documento, numero_documento);
ALTER TABLE ONLY generales.terceros
    ADD CONSTRAINT terceros_pkey PRIMARY KEY (id);
CREATE TRIGGER trg_contactos_updated_at BEFORE UPDATE ON generales.contactos FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();
CREATE TRIGGER trg_terceros_updated_at BEFORE UPDATE ON generales.terceros FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();
ALTER TABLE ONLY generales.contactos
    ADD CONSTRAINT contactos_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES generales.terceros(id) ON DELETE CASCADE;
