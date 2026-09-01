-- Migración: mover facturacion.terceros a generales.terceros
-- Ejecutar en DBeaver o psql contra la BD existente
-- Tolerante a que generales.terceros ya exista (por 01_schema.sql)

BEGIN;

CREATE SCHEMA IF NOT EXISTS generales;

-- Tabla destino: crearla SOLO si no existe
CREATE TABLE IF NOT EXISTS generales.terceros (LIKE facturacion.terceros INCLUDING DEFAULTS INCLUDING CONSTRAINTS INCLUDING INDEXES);

-- Copiar datos (ON CONFLICT DO NOTHING si ya hay registros)
INSERT INTO generales.terceros (id, tipo_documento, numero_documento, digito_verificacion, tipo_persona, razon_social, direccion, codigo_ciudad, ciudad, codigo_departamento, departamento, codigo_postal, pais, telefono, email, es_propio, created_at, updated_at, es_cliente, es_proveedor)
SELECT id, tipo_documento, numero_documento, digito_verificacion, tipo_persona, razon_social, direccion, codigo_ciudad, ciudad, codigo_departamento, departamento, codigo_postal, pais, telefono, email, es_propio, created_at, updated_at, es_cliente, es_proveedor
FROM facturacion.terceros
ON CONFLICT (id) DO NOTHING;

-- Actualizar secuencia (si la tabla recién se creó, la secuencia se llama generales.terceros_id_seq)
DO $$
DECLARE
  v_max_id INT;
  seq_name TEXT;
BEGIN
  SELECT MAX(id) INTO v_max_id FROM generales.terceros;
  IF v_max_id IS NOT NULL THEN
    -- Buscar el nombre real de la secuencia
    SELECT pg_get_serial_sequence('generales.terceros', 'id') INTO seq_name;
    IF seq_name IS NOT NULL THEN
      EXECUTE 'SELECT setval($1, $2)' USING seq_name, v_max_id;
    END IF;
  END IF;
END $$;

-- Eliminar FKs que referencian facturacion.terceros
ALTER TABLE IF EXISTS facturacion.ventas      DROP CONSTRAINT IF EXISTS facturas_emisor_id_fkey;
ALTER TABLE IF EXISTS facturacion.ventas      DROP CONSTRAINT IF EXISTS facturas_receptor_id_fkey;
ALTER TABLE IF EXISTS facturacion.ventas      DROP CONSTRAINT IF EXISTS ventas_emisor_id_fkey;
ALTER TABLE IF EXISTS facturacion.ventas      DROP CONSTRAINT IF EXISTS ventas_receptor_id_fkey;
ALTER TABLE IF EXISTS compras.facturas_compra DROP CONSTRAINT IF EXISTS facturas_compra_proveedor_id_fkey;
ALTER TABLE IF EXISTS compras.facturas_compra DROP CONSTRAINT IF EXISTS facturas_compra_receptor_id_fkey;
ALTER TABLE IF EXISTS gastos.gastos           DROP CONSTRAINT IF EXISTS gastos_proveedor_id_fkey;
ALTER TABLE IF EXISTS cartera.pagos           DROP CONSTRAINT IF EXISTS pagos_cliente_id_fkey;
ALTER TABLE IF EXISTS cartera.pagos           DROP CONSTRAINT IF EXISTS pagos_cliente_id_fkey1;
ALTER TABLE IF EXISTS helpdesk.recursos       DROP CONSTRAINT IF EXISTS recursos_cliente_id_fkey;
ALTER TABLE IF EXISTS generales.contactos     DROP CONSTRAINT IF EXISTS contactos_cliente_id_fkey;
ALTER TABLE IF EXISTS helpdesk.casos          DROP CONSTRAINT IF EXISTS casos_cliente_id_fkey;
ALTER TABLE IF EXISTS helpdesk.casos          DROP CONSTRAINT IF EXISTS casos_cliente_id_fkey1;

-- Caída de seguridad: eliminar cualquier otra FK que aun referencie facturacion.terceros
DO $$
DECLARE
    r RECORD;
BEGIN
    FOR r IN (
        SELECT con.conname, con.conrelid::regclass AS table_name
        FROM pg_constraint con
        JOIN pg_class cl ON cl.oid = con.conrelid
        JOIN pg_namespace nsp ON nsp.oid = cl.relnamespace
        WHERE con.confrelid = 'facturacion.terceros'::regclass
          AND con.contype = 'f'
    ) LOOP
        EXECUTE 'ALTER TABLE ' || r.table_name || ' DROP CONSTRAINT ' || quote_ident(r.conname);
    END LOOP;
END $$;

-- Eliminar trigger antiguo
DROP TRIGGER IF EXISTS trg_terceros_updated_at ON facturacion.terceros;

-- Eliminar tabla antigua
DROP TABLE IF EXISTS facturacion.terceros CASCADE;

-- Recrear la secuencia porque el DROP CASCADE eliminó facturacion.terceros_id_seq
-- (LIKE ... INCLUDING DEFAULTS copió el default apuntando a esa secuencia antigua)
CREATE SEQUENCE IF NOT EXISTS generales.terceros_id_seq;
ALTER TABLE generales.terceros ALTER COLUMN id SET DEFAULT nextval('generales.terceros_id_seq');
SELECT setval('generales.terceros_id_seq', COALESCE((SELECT MAX(id) FROM generales.terceros), 1));

-- Recrear FKs apuntando a generales.terceros
ALTER TABLE facturacion.ventas      ADD CONSTRAINT ventas_emisor_id_fkey   FOREIGN KEY (emisor_id)   REFERENCES generales.terceros(id);
ALTER TABLE facturacion.ventas      ADD CONSTRAINT ventas_receptor_id_fkey FOREIGN KEY (receptor_id) REFERENCES generales.terceros(id);
ALTER TABLE compras.facturas_compra ADD CONSTRAINT facturas_compra_proveedor_id_fkey FOREIGN KEY (proveedor_id) REFERENCES generales.terceros(id);
ALTER TABLE compras.facturas_compra ADD CONSTRAINT facturas_compra_receptor_id_fkey  FOREIGN KEY (receptor_id)  REFERENCES generales.terceros(id);
ALTER TABLE gastos.gastos           ADD CONSTRAINT gastos_proveedor_id_fkey  FOREIGN KEY (proveedor_id) REFERENCES generales.terceros(id);
ALTER TABLE cartera.pagos           ADD CONSTRAINT pagos_cliente_id_fkey     FOREIGN KEY (cliente_id)   REFERENCES generales.terceros(id);
ALTER TABLE helpdesk.recursos       ADD CONSTRAINT recursos_cliente_id_fkey  FOREIGN KEY (cliente_id)   REFERENCES generales.terceros(id);
ALTER TABLE generales.contactos     ADD CONSTRAINT contactos_cliente_id_fkey FOREIGN KEY (cliente_id)   REFERENCES generales.terceros(id) ON DELETE CASCADE;
ALTER TABLE helpdesk.casos          ADD CONSTRAINT casos_cliente_id_fkey     FOREIGN KEY (cliente_id)   REFERENCES generales.terceros(id);

-- Crear trigger en generales.terceros
DROP TRIGGER IF EXISTS trg_terceros_updated_at ON generales.terceros;
CREATE TRIGGER trg_terceros_updated_at
    BEFORE UPDATE ON generales.terceros
    FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

COMMIT;

-- ALTER ROLE fuera de transacción
ALTER ROLE maxan_user SET search_path TO facturacion, compras, inventario, gastos, cartera, usuarios, generales, helpdesk, public;
