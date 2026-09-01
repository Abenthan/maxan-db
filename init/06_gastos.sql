-- ============================================================
-- maxan-db - 06_gastos.sql (generado por tools/build_init.ps1)
-- Objetos locales del schema 'gastos': tablas, secuencias,
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
CREATE SCHEMA IF NOT EXISTS gastos;

CREATE TABLE gastos.gastos (
    id integer NOT NULL,
    factura_compra_id integer,
    proveedor_id integer,
    producto_id integer,
    venta_item_id integer,
    descripcion text NOT NULL,
    clasificacion character varying(20) NOT NULL,
    cantidad numeric(18,6) DEFAULT 1 NOT NULL,
    valor_unitario numeric(18,2) NOT NULL,
    valor_total numeric(18,2) NOT NULL,
    fecha date DEFAULT CURRENT_DATE NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    codigo_producto character varying(50),
    CONSTRAINT gastos_check CHECK ((NOT ((producto_id IS NOT NULL) AND (venta_item_id IS NOT NULL))))
);
CREATE TABLE gastos.clasificaciones (
    id integer NOT NULL,
    nombre character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT now()
);
CREATE SEQUENCE gastos.clasificaciones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE gastos.clasificaciones_id_seq OWNED BY gastos.clasificaciones.id;
CREATE SEQUENCE gastos.gastos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE gastos.gastos_id_seq OWNED BY gastos.gastos.id;
ALTER TABLE ONLY gastos.clasificaciones ALTER COLUMN id SET DEFAULT nextval('gastos.clasificaciones_id_seq'::regclass);
ALTER TABLE ONLY gastos.gastos ALTER COLUMN id SET DEFAULT nextval('gastos.gastos_id_seq'::regclass);
ALTER TABLE ONLY gastos.clasificaciones
    ADD CONSTRAINT clasificaciones_nombre_key UNIQUE (nombre);
ALTER TABLE ONLY gastos.clasificaciones
    ADD CONSTRAINT clasificaciones_pkey PRIMARY KEY (id);
ALTER TABLE ONLY gastos.gastos
    ADD CONSTRAINT gastos_pkey PRIMARY KEY (id);
CREATE INDEX idx_gastos_factura_compra ON gastos.gastos USING btree (factura_compra_id);
CREATE INDEX idx_gastos_producto ON gastos.gastos USING btree (producto_id);
CREATE INDEX idx_gastos_venta_item ON gastos.gastos USING btree (venta_item_id);
CREATE TRIGGER trg_gastos_crear_entrada AFTER INSERT OR UPDATE OF producto_id ON gastos.gastos FOR EACH ROW EXECUTE FUNCTION inventario.fn_crear_entrada();
CREATE TRIGGER trg_gastos_set_clasificacion BEFORE INSERT OR UPDATE ON gastos.gastos FOR EACH ROW EXECUTE FUNCTION gastos.fn_set_clasificacion();
CREATE TRIGGER trg_gastos_updated_at BEFORE UPDATE ON gastos.gastos FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();
ALTER TABLE ONLY gastos.gastos
    ADD CONSTRAINT fk_gasto_clasificacion FOREIGN KEY (clasificacion) REFERENCES gastos.clasificaciones(nombre);
