-- ============================================================
-- maxan-db - 01_usuarios.sql (generado por tools/build_init.ps1)
-- Objetos locales del schema 'usuarios': tablas, secuencias,
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
CREATE SCHEMA IF NOT EXISTS usuarios;

CREATE TABLE usuarios.empresas (
    id integer NOT NULL,
    nombre character varying(255) NOT NULL,
    nit character varying(50) NOT NULL,
    activa boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);
CREATE SEQUENCE usuarios.empresas_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE usuarios.empresas_id_seq OWNED BY usuarios.empresas.id;
CREATE TABLE usuarios.permisos (
    id integer NOT NULL,
    codigo character varying(100) NOT NULL,
    nombre character varying(255) NOT NULL,
    descripcion text,
    modulo character varying(100),
    created_at timestamp with time zone DEFAULT now()
);
CREATE SEQUENCE usuarios.permisos_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE usuarios.permisos_id_seq OWNED BY usuarios.permisos.id;
CREATE TABLE usuarios.roles (
    id integer NOT NULL,
    nombre character varying(100) NOT NULL,
    descripcion text,
    created_at timestamp with time zone DEFAULT now()
);
CREATE SEQUENCE usuarios.roles_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE usuarios.roles_id_seq OWNED BY usuarios.roles.id;
CREATE TABLE usuarios.roles_permisos (
    rol_id integer NOT NULL,
    permiso_id integer NOT NULL
);
CREATE TABLE usuarios.sesiones (
    id integer NOT NULL,
    usuario_id integer NOT NULL,
    token_hash character varying(64) NOT NULL,
    expires_at timestamp with time zone NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL
);
CREATE SEQUENCE usuarios.sesiones_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE usuarios.sesiones_id_seq OWNED BY usuarios.sesiones.id;
CREATE TABLE usuarios.usuarios (
    id integer NOT NULL,
    empresa_id integer NOT NULL,
    username character varying(100) NOT NULL,
    email character varying(255) NOT NULL,
    password_hash character varying(255) NOT NULL,
    nombres character varying(255) NOT NULL,
    apellidos character varying(255) NOT NULL,
    activo boolean DEFAULT true,
    created_at timestamp with time zone DEFAULT now(),
    updated_at timestamp with time zone DEFAULT now()
);
CREATE SEQUENCE usuarios.usuarios_id_seq
    AS integer
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;
ALTER SEQUENCE usuarios.usuarios_id_seq OWNED BY usuarios.usuarios.id;
CREATE TABLE usuarios.usuarios_roles (
    usuario_id integer NOT NULL,
    rol_id integer NOT NULL
);
ALTER TABLE ONLY usuarios.empresas ALTER COLUMN id SET DEFAULT nextval('usuarios.empresas_id_seq'::regclass);
ALTER TABLE ONLY usuarios.permisos ALTER COLUMN id SET DEFAULT nextval('usuarios.permisos_id_seq'::regclass);
ALTER TABLE ONLY usuarios.roles ALTER COLUMN id SET DEFAULT nextval('usuarios.roles_id_seq'::regclass);
ALTER TABLE ONLY usuarios.sesiones ALTER COLUMN id SET DEFAULT nextval('usuarios.sesiones_id_seq'::regclass);
ALTER TABLE ONLY usuarios.usuarios ALTER COLUMN id SET DEFAULT nextval('usuarios.usuarios_id_seq'::regclass);
ALTER TABLE ONLY usuarios.empresas
    ADD CONSTRAINT empresas_nit_key UNIQUE (nit);
ALTER TABLE ONLY usuarios.empresas
    ADD CONSTRAINT empresas_pkey PRIMARY KEY (id);
ALTER TABLE ONLY usuarios.permisos
    ADD CONSTRAINT permisos_codigo_key UNIQUE (codigo);
ALTER TABLE ONLY usuarios.permisos
    ADD CONSTRAINT permisos_pkey PRIMARY KEY (id);
ALTER TABLE ONLY usuarios.roles
    ADD CONSTRAINT roles_nombre_key UNIQUE (nombre);
ALTER TABLE ONLY usuarios.roles_permisos
    ADD CONSTRAINT roles_permisos_pkey PRIMARY KEY (rol_id, permiso_id);
ALTER TABLE ONLY usuarios.roles
    ADD CONSTRAINT roles_pkey PRIMARY KEY (id);
ALTER TABLE ONLY usuarios.sesiones
    ADD CONSTRAINT sesiones_pkey PRIMARY KEY (id);
ALTER TABLE ONLY usuarios.usuarios
    ADD CONSTRAINT usuarios_email_key UNIQUE (email);
ALTER TABLE ONLY usuarios.usuarios
    ADD CONSTRAINT usuarios_pkey PRIMARY KEY (id);
ALTER TABLE ONLY usuarios.usuarios_roles
    ADD CONSTRAINT usuarios_roles_pkey PRIMARY KEY (usuario_id, rol_id);
ALTER TABLE ONLY usuarios.usuarios
    ADD CONSTRAINT usuarios_username_key UNIQUE (username);
CREATE INDEX idx_sesiones_token_hash ON usuarios.sesiones USING btree (token_hash);
CREATE INDEX idx_sesiones_usuario_id ON usuarios.sesiones USING btree (usuario_id);
CREATE TRIGGER trg_empresas_updated_at BEFORE UPDATE ON usuarios.empresas FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();
CREATE TRIGGER trg_usuarios_updated_at BEFORE UPDATE ON usuarios.usuarios FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();
ALTER TABLE ONLY usuarios.roles_permisos
    ADD CONSTRAINT roles_permisos_permiso_id_fkey FOREIGN KEY (permiso_id) REFERENCES usuarios.permisos(id) ON DELETE CASCADE;
ALTER TABLE ONLY usuarios.roles_permisos
    ADD CONSTRAINT roles_permisos_rol_id_fkey FOREIGN KEY (rol_id) REFERENCES usuarios.roles(id) ON DELETE CASCADE;
ALTER TABLE ONLY usuarios.sesiones
    ADD CONSTRAINT sesiones_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES usuarios.usuarios(id) ON DELETE CASCADE;
ALTER TABLE ONLY usuarios.usuarios
    ADD CONSTRAINT usuarios_empresa_id_fkey FOREIGN KEY (empresa_id) REFERENCES usuarios.empresas(id);
ALTER TABLE ONLY usuarios.usuarios_roles
    ADD CONSTRAINT usuarios_roles_rol_id_fkey FOREIGN KEY (rol_id) REFERENCES usuarios.roles(id) ON DELETE CASCADE;
ALTER TABLE ONLY usuarios.usuarios_roles
    ADD CONSTRAINT usuarios_roles_usuario_id_fkey FOREIGN KEY (usuario_id) REFERENCES usuarios.usuarios(id) ON DELETE CASCADE;
