-- ============================================================
-- maxan-db - 05_inventario.sql (generado por tools/build_init.ps1)
-- Objetos locales del schema 'inventario': tablas, secuencias,
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
CREATE SCHEMA IF NOT EXISTS inventario;

CREATE TABLE inventario.salidas (
    id integer NOT NULL,
    factura_item_id integer NOT NULL,
    producto_id integer NOT NULL,
    cantidad numeric(18,6) NOT NULL,
    costo_total numeric(18,2) NOT NULL,
    created_at timestamp without time zone DEFAULT now()
);
CREATE TABLE inventario.categorias (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    created_at timestamp without time zone DEFAULT now()
);
CREATE SEQUENCE inventario.categorias_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE inventario.categorias_id_seq OWNED BY inventario.categorias.id;
CREATE TABLE inventario.entradas (
    id integer NOT NULL,
    gasto_id integer,
    producto_id integer NOT NULL,
    cantidad numeric(18,6) NOT NULL,
    cantidad_disponible numeric(18,6) NOT NULL,
    costo_unitario numeric(18,2) NOT NULL,
    fecha date NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    origen character varying(20) DEFAULT 'gasto'::character varying NOT NULL,
    referencia text
);
CREATE SEQUENCE inventario.entradas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE inventario.entradas_id_seq OWNED BY inventario.entradas.id;
CREATE TABLE inventario.productos (
    id integer NOT NULL,
    nombre character varying(255) NOT NULL,
    categoria character varying(100),
    inventariable boolean DEFAULT true NOT NULL,
    unidad_medida character varying(10) DEFAULT 'UND'::character varying,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    codigo character varying(50) NOT NULL
);
CREATE SEQUENCE inventario.productos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE inventario.productos_id_seq OWNED BY inventario.productos.id;
CREATE TABLE inventario.salida_detalle (
    id integer NOT NULL,
    salida_id integer NOT NULL,
    entrada_id integer NOT NULL,
    cantidad_consumida numeric(18,6) NOT NULL,
    costo_unitario numeric(18,2) NOT NULL
);
CREATE SEQUENCE inventario.salida_detalle_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE inventario.salida_detalle_id_seq OWNED BY inventario.salida_detalle.id;
CREATE SEQUENCE inventario.salidas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE inventario.salidas_id_seq OWNED BY inventario.salidas.id;
CREATE TABLE inventario.imagenes (
    id integer NOT NULL,
    producto_id integer NOT NULL,
    url text NOT NULL,
    es_principal boolean DEFAULT false NOT NULL,
    orden integer DEFAULT 0 NOT NULL,
    created_at timestamp without time zone DEFAULT now()
);
CREATE SEQUENCE inventario.imagenes_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE inventario.imagenes_id_seq OWNED BY inventario.imagenes.id;
ALTER TABLE ONLY inventario.categorias ALTER COLUMN id SET DEFAULT nextval('inventario.categorias_id_seq'::regclass);
ALTER TABLE ONLY inventario.entradas ALTER COLUMN id SET DEFAULT nextval('inventario.entradas_id_seq'::regclass);
ALTER TABLE ONLY inventario.productos ALTER COLUMN id SET DEFAULT nextval('inventario.productos_id_seq'::regclass);
ALTER TABLE ONLY inventario.salida_detalle ALTER COLUMN id SET DEFAULT nextval('inventario.salida_detalle_id_seq'::regclass);
ALTER TABLE ONLY inventario.salidas ALTER COLUMN id SET DEFAULT nextval('inventario.salidas_id_seq'::regclass);
ALTER TABLE ONLY inventario.imagenes ALTER COLUMN id SET DEFAULT nextval('inventario.imagenes_id_seq'::regclass);
ALTER TABLE ONLY inventario.categorias
    ADD CONSTRAINT categorias_nombre_key UNIQUE (nombre);
ALTER TABLE ONLY inventario.categorias
    ADD CONSTRAINT categorias_pkey PRIMARY KEY (id);
ALTER TABLE ONLY inventario.entradas
    ADD CONSTRAINT entradas_pkey PRIMARY KEY (id);
ALTER TABLE ONLY inventario.productos
    ADD CONSTRAINT productos_pkey PRIMARY KEY (id);
ALTER TABLE ONLY inventario.salida_detalle
    ADD CONSTRAINT salida_detalle_pkey PRIMARY KEY (id);
ALTER TABLE ONLY inventario.salidas
    ADD CONSTRAINT salidas_pkey PRIMARY KEY (id);
ALTER TABLE ONLY inventario.imagenes
    ADD CONSTRAINT imagenes_pkey PRIMARY KEY (id);
ALTER TABLE ONLY inventario.productos
    ADD CONSTRAINT uq_productos_codigo UNIQUE (codigo);
CREATE INDEX idx_entradas_producto_fecha ON inventario.entradas USING btree (producto_id, fecha, id);
CREATE INDEX idx_imagenes_producto ON inventario.imagenes USING btree (producto_id);
CREATE UNIQUE INDEX uq_imagenes_principal ON inventario.imagenes USING btree (producto_id) WHERE es_principal = TRUE;
CREATE TRIGGER trg_productos_updated_at BEFORE UPDATE ON inventario.productos FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();
ALTER TABLE ONLY inventario.entradas
    ADD CONSTRAINT entradas_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES inventario.productos(id);
ALTER TABLE ONLY inventario.salida_detalle
    ADD CONSTRAINT salida_detalle_entrada_id_fkey FOREIGN KEY (entrada_id) REFERENCES inventario.entradas(id);
ALTER TABLE ONLY inventario.salida_detalle
    ADD CONSTRAINT salida_detalle_salida_id_fkey FOREIGN KEY (salida_id) REFERENCES inventario.salidas(id) ON DELETE CASCADE;
ALTER TABLE ONLY inventario.salidas
    ADD CONSTRAINT salidas_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES inventario.productos(id);
ALTER TABLE ONLY inventario.imagenes
    ADD CONSTRAINT imagenes_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES inventario.productos(id) ON DELETE CASCADE;
