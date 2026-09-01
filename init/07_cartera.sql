-- ============================================================
-- maxan-db - 07_cartera.sql (generado por tools/build_init.ps1)
-- Objetos locales del schema 'cartera': tablas, secuencias,
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
CREATE SCHEMA IF NOT EXISTS cartera;

CREATE TABLE cartera.medios_pago (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    created_at timestamp without time zone DEFAULT now()
);
CREATE SEQUENCE cartera.medios_pago_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE cartera.medios_pago_id_seq OWNED BY cartera.medios_pago.id;
CREATE TABLE cartera.pago_aplicaciones (
    id integer NOT NULL,
    pago_id integer NOT NULL,
    venta_id integer NOT NULL,
    valor_aplicado numeric(18,2) NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    CONSTRAINT pago_aplicaciones_valor_aplicado_check CHECK ((valor_aplicado > (0)::numeric))
);
CREATE SEQUENCE cartera.pago_aplicaciones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE cartera.pago_aplicaciones_id_seq OWNED BY cartera.pago_aplicaciones.id;
CREATE TABLE cartera.pagos (
    id integer NOT NULL,
    cliente_id integer NOT NULL,
    medio_pago_id integer,
    referencia character varying(100),
    fecha_pago date DEFAULT CURRENT_DATE NOT NULL,
    valor_total numeric(18,2) NOT NULL,
    observaciones text,
    anulado boolean DEFAULT false NOT NULL,
    created_at timestamp without time zone DEFAULT now(),
    updated_at timestamp without time zone DEFAULT now(),
    CONSTRAINT pagos_valor_total_check CHECK ((valor_total > (0)::numeric))
);
CREATE SEQUENCE cartera.pagos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE cartera.pagos_id_seq OWNED BY cartera.pagos.id;
ALTER TABLE ONLY cartera.medios_pago ALTER COLUMN id SET DEFAULT nextval('cartera.medios_pago_id_seq'::regclass);
ALTER TABLE ONLY cartera.pago_aplicaciones ALTER COLUMN id SET DEFAULT nextval('cartera.pago_aplicaciones_id_seq'::regclass);
ALTER TABLE ONLY cartera.pagos ALTER COLUMN id SET DEFAULT nextval('cartera.pagos_id_seq'::regclass);
ALTER TABLE ONLY cartera.medios_pago
    ADD CONSTRAINT medios_pago_nombre_key UNIQUE (nombre);
ALTER TABLE ONLY cartera.medios_pago
    ADD CONSTRAINT medios_pago_pkey PRIMARY KEY (id);
ALTER TABLE ONLY cartera.pago_aplicaciones
    ADD CONSTRAINT pago_aplicaciones_pago_id_venta_id_key UNIQUE (pago_id, venta_id);
ALTER TABLE ONLY cartera.pago_aplicaciones
    ADD CONSTRAINT pago_aplicaciones_pkey PRIMARY KEY (id);
ALTER TABLE ONLY cartera.pagos
    ADD CONSTRAINT pagos_pkey PRIMARY KEY (id);
CREATE INDEX idx_pago_aplicaciones_pago ON cartera.pago_aplicaciones USING btree (pago_id);
CREATE INDEX idx_pago_aplicaciones_venta ON cartera.pago_aplicaciones USING btree (venta_id);
CREATE INDEX idx_pagos_cliente ON cartera.pagos USING btree (cliente_id);
CREATE INDEX idx_pagos_fecha ON cartera.pagos USING btree (fecha_pago);
CREATE TRIGGER trg_pago_aplicaciones_actualizar_saldo AFTER INSERT OR DELETE ON cartera.pago_aplicaciones FOR EACH ROW EXECUTE FUNCTION cartera.fn_actualizar_saldo();
CREATE TRIGGER trg_pagos_updated_at BEFORE UPDATE ON cartera.pagos FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();
ALTER TABLE ONLY cartera.pago_aplicaciones
    ADD CONSTRAINT pago_aplicaciones_pago_id_fkey FOREIGN KEY (pago_id) REFERENCES cartera.pagos(id) ON DELETE CASCADE;
ALTER TABLE ONLY cartera.pagos
    ADD CONSTRAINT pagos_medio_pago_id_fkey FOREIGN KEY (medio_pago_id) REFERENCES cartera.medios_pago(id);
