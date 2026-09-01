CREATE SCHEMA IF NOT EXISTS usuarios;

CREATE TABLE usuarios.empresas (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(255) NOT NULL,
  nit VARCHAR(50) UNIQUE NOT NULL,
  activa BOOLEAN DEFAULT true,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER trg_empresas_updated_at
  BEFORE UPDATE ON usuarios.empresas
  FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

CREATE TABLE usuarios.usuarios (
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

CREATE TRIGGER trg_usuarios_updated_at
  BEFORE UPDATE ON usuarios.usuarios
  FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

CREATE TABLE usuarios.roles (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(100) UNIQUE NOT NULL,
  descripcion TEXT,
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE usuarios.permisos (
  id SERIAL PRIMARY KEY,
  codigo VARCHAR(100) UNIQUE NOT NULL,
  nombre VARCHAR(255) NOT NULL,
  descripcion TEXT,
  modulo VARCHAR(100),
  created_at TIMESTAMPTZ DEFAULT now()
);

CREATE TABLE usuarios.roles_permisos (
  rol_id INTEGER NOT NULL REFERENCES usuarios.roles(id) ON DELETE CASCADE,
  permiso_id INTEGER NOT NULL REFERENCES usuarios.permisos(id) ON DELETE CASCADE,
  PRIMARY KEY (rol_id, permiso_id)
);

CREATE TABLE usuarios.usuarios_roles (
  usuario_id INTEGER NOT NULL REFERENCES usuarios.usuarios(id) ON DELETE CASCADE,
  rol_id INTEGER NOT NULL REFERENCES usuarios.roles(id) ON DELETE CASCADE,
  PRIMARY KEY (usuario_id, rol_id)
);
