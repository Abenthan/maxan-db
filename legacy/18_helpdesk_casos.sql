-- ============================================================
-- Módulo Helpdesk - Extensión: Casos de soporte, contactos
-- ============================================================

-- ------------------------------------------------------------------
-- 1. CATEGORÍAS DE CASO (editables por el usuario)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS helpdesk.categorias_caso (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL UNIQUE,
  color VARCHAR(7) DEFAULT '#6B7280',
  activo BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now()
);

INSERT INTO helpdesk.categorias_caso (nombre, color) VALUES
  ('Soporte Técnico', '#3B82F6'),
  ('Falla / Error', '#EF4444'),
  ('Instalación', '#10B981'),
  ('Consulta', '#F59E0B'),
  ('Mantenimiento', '#8B5CF6'),
  ('Configuración', '#14B8A6'),
  ('Otro', '#6B7280')
ON CONFLICT (nombre) DO NOTHING;

-- ------------------------------------------------------------------
-- 2. CONTACTOS (personas de contacto de clientes)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS helpdesk.contactos (
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

DROP TRIGGER IF EXISTS trg_contactos_updated_at ON helpdesk.contactos;
CREATE TRIGGER trg_contactos_updated_at
  BEFORE UPDATE ON helpdesk.contactos
  FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

-- ------------------------------------------------------------------
-- 3. CASOS (tickets de soporte)
-- ------------------------------------------------------------------
CREATE SEQUENCE IF NOT EXISTS helpdesk.caso_numero_seq START 1;

CREATE TABLE IF NOT EXISTS helpdesk.casos (
  id SERIAL PRIMARY KEY,
  numero VARCHAR(20) UNIQUE DEFAULT ('CASO-' || LPAD(nextval('helpdesk.caso_numero_seq')::TEXT, 4, '0')),
  titulo VARCHAR(300) NOT NULL,
  descripcion TEXT,
  categoria_id INTEGER REFERENCES helpdesk.categorias_caso(id),
  recurso_id INTEGER REFERENCES helpdesk.recursos(id),
  cliente_id INTEGER REFERENCES generales.terceros(id),
  contacto_id INTEGER REFERENCES helpdesk.contactos(id),
  tecnico_id INTEGER REFERENCES usuarios.usuarios(id),
  estado VARCHAR(20) DEFAULT 'Pendiente'
    CHECK (estado IN ('Pendiente', 'En Progreso', 'Completado', 'Cancelado')),
  telegram_chat_id VARCHAR(100),
  telegram_topic_id VARCHAR(100),
  whatsapp_chat_id VARCHAR(100),
  fuente VARCHAR(20) DEFAULT 'Manual'
    CHECK (fuente IN ('Manual', 'WhatsApp', 'Telegram', 'Email', 'Web')),
  ai_report TEXT,
  solucion TEXT,
  venta_item_id INTEGER REFERENCES facturacion.ventas_items(id),
  resumen TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

DROP TRIGGER IF EXISTS trg_casos_updated_at ON helpdesk.casos;
CREATE TRIGGER trg_casos_updated_at
  BEFORE UPDATE ON helpdesk.casos
  FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

-- ------------------------------------------------------------------
-- 4. CASOS_CONTACTOS (relación muchos-a-muchos)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS helpdesk.casos_contactos (
  caso_id INTEGER NOT NULL REFERENCES helpdesk.casos(id) ON DELETE CASCADE,
  contacto_id INTEGER NOT NULL REFERENCES helpdesk.contactos(id) ON DELETE CASCADE,
  PRIMARY KEY (caso_id, contacto_id)
);

-- ------------------------------------------------------------------
-- 5. CASO_DETALLES (bitácora del caso)
-- ------------------------------------------------------------------
CREATE TABLE IF NOT EXISTS helpdesk.caso_detalles (
  id SERIAL PRIMARY KEY,
  caso_id INTEGER NOT NULL REFERENCES helpdesk.casos(id) ON DELETE CASCADE,
  creado_por INTEGER REFERENCES usuarios.usuarios(id),
  contenido TEXT NOT NULL,
  tipo VARCHAR(20) DEFAULT 'Comentario'
    CHECK (tipo IN ('Comentario', 'Diagnóstico', 'Solución', 'Acuerdo', 'Sistema')),
  created_at TIMESTAMPTZ DEFAULT now()
);
