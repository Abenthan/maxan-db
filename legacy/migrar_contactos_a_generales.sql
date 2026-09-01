-- Migración: mover helpdesk.contactos a generales.contactos
-- Ejecutar en DBeaver o psql contra la BD existente

BEGIN;

-- 1. Crear schema generales
CREATE SCHEMA IF NOT EXISTS generales;

-- 2. Crear tabla generales.contactos (misma estructura)
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

-- 3. Copiar datos
INSERT INTO generales.contactos (id, cliente_id, nombre, telefono, email, whatsapp, cargo, activo, created_at, updated_at)
SELECT id, cliente_id, nombre, telefono, email, whatsapp, cargo, activo, created_at, updated_at
FROM helpdesk.contactos;

-- 4. Actualizar secuencia de generales.contactos al máximo id
SELECT setval('generales.contactos_id_seq', COALESCE((SELECT MAX(id) FROM generales.contactos), 1));

-- 5. Eliminar FKs existentes que referencian helpdesk.contactos
ALTER TABLE IF EXISTS helpdesk.casos DROP CONSTRAINT IF EXISTS casos_contacto_id_fkey;
ALTER TABLE IF EXISTS helpdesk.casos_contactos DROP CONSTRAINT IF EXISTS casos_contactos_contacto_id_fkey;

-- 6. Eliminar tabla helpdesk.contactos (y su secuencia)
DROP TABLE IF EXISTS helpdesk.contactos CASCADE;

-- 7. Recrear FKs apuntando a generales.contactos
ALTER TABLE helpdesk.casos ADD CONSTRAINT casos_contacto_id_fkey FOREIGN KEY (contacto_id) REFERENCES generales.contactos(id);
ALTER TABLE helpdesk.casos_contactos ADD CONSTRAINT casos_contactos_contacto_id_fkey FOREIGN KEY (contacto_id) REFERENCES generales.contactos(id) ON DELETE CASCADE;

-- 8. Actualizar search_path
ALTER ROLE maxan_user SET search_path TO facturacion, compras, inventario, gastos, cartera, usuarios, generales, helpdesk, public;

-- 9. Crear trigger en generales.contactos
DROP TRIGGER IF EXISTS trg_contactos_updated_at ON generales.contactos;
CREATE TRIGGER trg_contactos_updated_at
  BEFORE UPDATE ON generales.contactos
  FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

COMMIT;
