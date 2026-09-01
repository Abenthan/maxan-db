-- ============================================================
-- maxan-db - 08_helpdesk.sql (generado por tools/build_init.ps1)
-- Objetos locales del schema 'helpdesk': tablas, secuencias,
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
CREATE SCHEMA IF NOT EXISTS helpdesk;

CREATE TABLE helpdesk.caso_detalles (
    id integer NOT NULL,
    caso_id integer NOT NULL,
    creado_por integer,
    contenido text NOT NULL,
    tipo character varying(20) DEFAULT 'Comentario'::character varying,
    created_at timestamp with time zone DEFAULT now(),
    recurso_id integer
);
CREATE SEQUENCE helpdesk.caso_detalles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE helpdesk.caso_detalles_id_seq OWNED BY helpdesk.caso_detalles.id;
CREATE SEQUENCE helpdesk.caso_numero_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
CREATE TABLE helpdesk.casos (
    id integer NOT NULL,
    numero character varying(20) DEFAULT ('CASO-'::text || lpad((nextval('helpdesk.caso_numero_seq'::regclass))::text, 4, '0'::text)),
    titulo character varying(300) NOT NULL,
    descripcion text,
    categoria_id integer,
    recurso_id integer,
    cliente_id integer,
    contacto_id integer,
    tecnico_id integer,
    estado character varying(20) DEFAULT 'Pendiente'::character varying,
    telegram_chat_id character varying(100),
    telegram_topic_id character varying(100),
    whatsapp_chat_id character varying(100),
    fuente character varying(20) DEFAULT 'Manual'::character varying,
    ai_report text,
    solucion text,
    venta_item_id integer,
    resumen text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT casos_estado_check CHECK (((estado)::text = ANY (ARRAY[('Pendiente'::character varying)::text, ('En Progreso'::character varying)::text, ('Completado'::character varying)::text, ('Cancelado'::character varying)::text]))),
    CONSTRAINT casos_fuente_check CHECK (((fuente)::text = ANY (ARRAY[('Manual'::character varying)::text, ('WhatsApp'::character varying)::text, ('Telegram'::character varying)::text, ('Email'::character varying)::text, ('Web'::character varying)::text])))
);
CREATE TABLE helpdesk.casos_contactos (
    caso_id integer NOT NULL,
    contacto_id integer NOT NULL
);
CREATE SEQUENCE helpdesk.casos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE helpdesk.casos_id_seq OWNED BY helpdesk.casos.id;
CREATE TABLE helpdesk.casos_recursos (
    caso_id integer NOT NULL,
    recurso_id integer NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);
CREATE TABLE helpdesk.categorias_caso (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    color character varying(7) DEFAULT '#6B7280'::character varying,
    activo boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now()
);
CREATE SEQUENCE helpdesk.categorias_caso_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE helpdesk.categorias_caso_id_seq OWNED BY helpdesk.categorias_caso.id;
CREATE TABLE helpdesk.categorias_mantenimiento (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    color character varying(7) DEFAULT '#6B7280'::character varying
);
CREATE SEQUENCE helpdesk.categorias_mantenimiento_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE helpdesk.categorias_mantenimiento_id_seq OWNED BY helpdesk.categorias_mantenimiento.id;
CREATE TABLE helpdesk.mantenimiento_detalles (
    id integer NOT NULL,
    mantenimiento_id integer NOT NULL,
    creado_por integer,
    contenido text NOT NULL,
    tipo character varying(20) DEFAULT 'Comentario'::character varying,
    created_at timestamp with time zone DEFAULT now(),
    CONSTRAINT mantenimiento_detalles_tipo_check CHECK (((tipo)::text = ANY (ARRAY[('Comentario'::character varying)::text, ('Diagnóstico'::character varying)::text, ('Solución'::character varying)::text, ('Repuesto'::character varying)::text, ('Acuerdo'::character varying)::text])))
);
CREATE SEQUENCE helpdesk.mantenimiento_detalles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE helpdesk.mantenimiento_detalles_id_seq OWNED BY helpdesk.mantenimiento_detalles.id;
CREATE TABLE helpdesk.mantenimientos (
    id integer NOT NULL,
    recurso_id integer NOT NULL,
    categoria_id integer NOT NULL,
    tecnico_id integer,
    titulo character varying(300) NOT NULL,
    descripcion text,
    prioridad character varying(20) DEFAULT 'Media'::character varying,
    estado character varying(20) DEFAULT 'Pendiente'::character varying,
    fecha_solicitud date DEFAULT CURRENT_DATE,
    fecha_ejecucion date,
    hora_inicio time without time zone,
    hora_fin time without time zone,
    costo_mano_obra numeric(12,2) DEFAULT 0,
    costo_repuestos numeric(12,2) DEFAULT 0,
    costo_total numeric(12,2) GENERATED ALWAYS AS ((costo_mano_obra + costo_repuestos)) STORED,
    venta_item_id integer,
    observaciones text,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    CONSTRAINT mantenimientos_estado_check CHECK (((estado)::text = ANY (ARRAY[('Pendiente'::character varying)::text, ('En Progreso'::character varying)::text, ('Completado'::character varying)::text, ('Facturado'::character varying)::text, ('Cancelado'::character varying)::text]))),
    CONSTRAINT mantenimientos_prioridad_check CHECK (((prioridad)::text = ANY (ARRAY[('Baja'::character varying)::text, ('Media'::character varying)::text, ('Alta'::character varying)::text, ('Crítica'::character varying)::text])))
);
CREATE SEQUENCE helpdesk.mantenimientos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE helpdesk.mantenimientos_id_seq OWNED BY helpdesk.mantenimientos.id;
CREATE TABLE helpdesk.recursos (
    id integer NOT NULL,
    cliente_id integer NOT NULL,
    nombre character varying(200) NOT NULL,
    tipo character varying(50) DEFAULT 'Computador'::character varying NOT NULL,
    marca character varying(100),
    modelo character varying(100),
    referencia character varying(100),
    serial character varying(100),
    procesador character varying(200),
    memoria_gb numeric(6,1),
    almacenamiento_gb numeric(8,1),
    sistema_operativo character varying(100),
    ubicacion character varying(200),
    descripcion text,
    activo boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now(),
    atributos jsonb DEFAULT '{}'::jsonb
);
CREATE SEQUENCE helpdesk.recursos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE helpdesk.recursos_id_seq OWNED BY helpdesk.recursos.id;
CREATE TABLE helpdesk.tipos_detalle (
    id integer NOT NULL,
    nombre character varying(50) NOT NULL,
    color character varying(7) DEFAULT '#92400e'::character varying NOT NULL,
    created_at timestamp with time zone DEFAULT now()
);
CREATE SEQUENCE helpdesk.tipos_detalle_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE helpdesk.tipos_detalle_id_seq OWNED BY helpdesk.tipos_detalle.id;
CREATE TABLE helpdesk.tipos_recurso (
    id integer NOT NULL,
    nombre character varying(50) NOT NULL,
    created_at timestamp without time zone DEFAULT now()
);
CREATE SEQUENCE helpdesk.tipos_recurso_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE helpdesk.tipos_recurso_id_seq OWNED BY helpdesk.tipos_recurso.id;
ALTER TABLE ONLY helpdesk.caso_detalles ALTER COLUMN id SET DEFAULT nextval('helpdesk.caso_detalles_id_seq'::regclass);
ALTER TABLE ONLY helpdesk.casos ALTER COLUMN id SET DEFAULT nextval('helpdesk.casos_id_seq'::regclass);
ALTER TABLE ONLY helpdesk.categorias_caso ALTER COLUMN id SET DEFAULT nextval('helpdesk.categorias_caso_id_seq'::regclass);
ALTER TABLE ONLY helpdesk.categorias_mantenimiento ALTER COLUMN id SET DEFAULT nextval('helpdesk.categorias_mantenimiento_id_seq'::regclass);
ALTER TABLE ONLY helpdesk.mantenimiento_detalles ALTER COLUMN id SET DEFAULT nextval('helpdesk.mantenimiento_detalles_id_seq'::regclass);
ALTER TABLE ONLY helpdesk.mantenimientos ALTER COLUMN id SET DEFAULT nextval('helpdesk.mantenimientos_id_seq'::regclass);
ALTER TABLE ONLY helpdesk.recursos ALTER COLUMN id SET DEFAULT nextval('helpdesk.recursos_id_seq'::regclass);
ALTER TABLE ONLY helpdesk.tipos_detalle ALTER COLUMN id SET DEFAULT nextval('helpdesk.tipos_detalle_id_seq'::regclass);
ALTER TABLE ONLY helpdesk.tipos_recurso ALTER COLUMN id SET DEFAULT nextval('helpdesk.tipos_recurso_id_seq'::regclass);
ALTER TABLE ONLY helpdesk.caso_detalles
    ADD CONSTRAINT caso_detalles_pkey PRIMARY KEY (id);
ALTER TABLE ONLY helpdesk.casos_contactos
    ADD CONSTRAINT casos_contactos_pkey PRIMARY KEY (caso_id, contacto_id);
ALTER TABLE ONLY helpdesk.casos
    ADD CONSTRAINT casos_numero_key UNIQUE (numero);
ALTER TABLE ONLY helpdesk.casos
    ADD CONSTRAINT casos_pkey PRIMARY KEY (id);
ALTER TABLE ONLY helpdesk.casos_recursos
    ADD CONSTRAINT casos_recursos_pkey PRIMARY KEY (caso_id, recurso_id);
ALTER TABLE ONLY helpdesk.categorias_caso
    ADD CONSTRAINT categorias_caso_nombre_key UNIQUE (nombre);
ALTER TABLE ONLY helpdesk.categorias_caso
    ADD CONSTRAINT categorias_caso_pkey PRIMARY KEY (id);
ALTER TABLE ONLY helpdesk.categorias_mantenimiento
    ADD CONSTRAINT categorias_mantenimiento_nombre_key UNIQUE (nombre);
ALTER TABLE ONLY helpdesk.categorias_mantenimiento
    ADD CONSTRAINT categorias_mantenimiento_pkey PRIMARY KEY (id);
ALTER TABLE ONLY helpdesk.mantenimiento_detalles
    ADD CONSTRAINT mantenimiento_detalles_pkey PRIMARY KEY (id);
ALTER TABLE ONLY helpdesk.mantenimientos
    ADD CONSTRAINT mantenimientos_pkey PRIMARY KEY (id);
ALTER TABLE ONLY helpdesk.recursos
    ADD CONSTRAINT recursos_pkey PRIMARY KEY (id);
ALTER TABLE ONLY helpdesk.recursos
    ADD CONSTRAINT recursos_serial_key UNIQUE (serial);
ALTER TABLE ONLY helpdesk.tipos_detalle
    ADD CONSTRAINT tipos_detalle_nombre_key UNIQUE (nombre);
ALTER TABLE ONLY helpdesk.tipos_detalle
    ADD CONSTRAINT tipos_detalle_pkey PRIMARY KEY (id);
ALTER TABLE ONLY helpdesk.tipos_recurso
    ADD CONSTRAINT tipos_recurso_nombre_key UNIQUE (nombre);
ALTER TABLE ONLY helpdesk.tipos_recurso
    ADD CONSTRAINT tipos_recurso_pkey PRIMARY KEY (id);
CREATE TRIGGER trg_casos_updated_at BEFORE UPDATE ON helpdesk.casos FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();
CREATE TRIGGER trg_mantenimientos_updated_at BEFORE UPDATE ON helpdesk.mantenimientos FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();
CREATE TRIGGER trg_recursos_updated_at BEFORE UPDATE ON helpdesk.recursos FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();
ALTER TABLE ONLY helpdesk.caso_detalles
    ADD CONSTRAINT caso_detalles_caso_id_fkey FOREIGN KEY (caso_id) REFERENCES helpdesk.casos(id) ON DELETE CASCADE;
ALTER TABLE ONLY helpdesk.caso_detalles
    ADD CONSTRAINT caso_detalles_recurso_id_fkey FOREIGN KEY (recurso_id) REFERENCES helpdesk.recursos(id) ON DELETE SET NULL;
ALTER TABLE ONLY helpdesk.caso_detalles
    ADD CONSTRAINT caso_detalles_tipo_fk FOREIGN KEY (tipo) REFERENCES helpdesk.tipos_detalle(nombre);
ALTER TABLE ONLY helpdesk.casos
    ADD CONSTRAINT casos_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES helpdesk.categorias_caso(id);
ALTER TABLE ONLY helpdesk.casos_contactos
    ADD CONSTRAINT casos_contactos_caso_id_fkey FOREIGN KEY (caso_id) REFERENCES helpdesk.casos(id) ON DELETE CASCADE;
ALTER TABLE ONLY helpdesk.casos
    ADD CONSTRAINT casos_recurso_id_fkey FOREIGN KEY (recurso_id) REFERENCES helpdesk.recursos(id);
ALTER TABLE ONLY helpdesk.casos_recursos
    ADD CONSTRAINT casos_recursos_caso_id_fkey FOREIGN KEY (caso_id) REFERENCES helpdesk.casos(id) ON DELETE CASCADE;
ALTER TABLE ONLY helpdesk.casos_recursos
    ADD CONSTRAINT casos_recursos_recurso_id_fkey FOREIGN KEY (recurso_id) REFERENCES helpdesk.recursos(id) ON DELETE CASCADE;
ALTER TABLE ONLY helpdesk.recursos
    ADD CONSTRAINT fk_recurso_tipo FOREIGN KEY (tipo) REFERENCES helpdesk.tipos_recurso(nombre) ON DELETE RESTRICT;
ALTER TABLE ONLY helpdesk.mantenimiento_detalles
    ADD CONSTRAINT mantenimiento_detalles_mantenimiento_id_fkey FOREIGN KEY (mantenimiento_id) REFERENCES helpdesk.mantenimientos(id) ON DELETE CASCADE;
ALTER TABLE ONLY helpdesk.mantenimientos
    ADD CONSTRAINT mantenimientos_categoria_id_fkey FOREIGN KEY (categoria_id) REFERENCES helpdesk.categorias_mantenimiento(id);
ALTER TABLE ONLY helpdesk.mantenimientos
    ADD CONSTRAINT mantenimientos_recurso_id_fkey FOREIGN KEY (recurso_id) REFERENCES helpdesk.recursos(id);
