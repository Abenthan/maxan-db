-- ============================================================
-- Módulo Helpdesk - Gestión de recursos informáticos de clientes
-- y mantenimientos / casos de soporte
-- ============================================================

CREATE SCHEMA IF NOT EXISTS helpdesk;

-- ------------------------------------------------------------------
-- 1. CATEGORÍAS DE MANTENIMIENTO
-- ------------------------------------------------------------------
CREATE TABLE helpdesk.categorias_mantenimiento (
  id SERIAL PRIMARY KEY,
  nombre VARCHAR(100) NOT NULL UNIQUE,
  color VARCHAR(7) DEFAULT '#6B7280'
);

INSERT INTO helpdesk.categorias_mantenimiento (nombre, color) VALUES
  ('Mantenimiento Preventivo', '#10B981'),
  ('Mantenimiento Correctivo', '#EF4444'),
  ('Instalación / Configuración', '#3B82F6'),
  ('Diagnóstico', '#F59E0B'),
  ('Soporte Remoto', '#8B5CF6'),
  ('Formateo / Backup', '#EC4899'),
  ('Redes / Cableado', '#14B8A6');

-- ------------------------------------------------------------------
-- 2. RECURSOS (equipos informáticos de clientes)
-- ------------------------------------------------------------------
CREATE TABLE helpdesk.recursos (
  id SERIAL PRIMARY KEY,
  cliente_id INTEGER NOT NULL REFERENCES generales.terceros(id),
  nombre VARCHAR(200) NOT NULL,
  tipo VARCHAR(50) NOT NULL DEFAULT 'Computador'
    CHECK (tipo IN ('Computador', 'Hosting', 'Office 365', 'Red', 'Celular', 'Impresora', 'Servidor', 'UPS', 'Cámara', 'Otro')),
  marca VARCHAR(100),
  modelo VARCHAR(100),
  referencia VARCHAR(100),
  serial VARCHAR(100) UNIQUE,
  procesador VARCHAR(200),
  memoria_gb NUMERIC(6,1),
  almacenamiento_gb NUMERIC(8,1),
  sistema_operativo VARCHAR(100),
  ubicacion VARCHAR(200),
  descripcion TEXT,
  activo BOOLEAN DEFAULT TRUE,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER trg_recursos_updated_at
  BEFORE UPDATE ON helpdesk.recursos
  FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

-- ------------------------------------------------------------------
-- 3. MANTENIMIENTOS (tickets / casos de soporte)
-- ------------------------------------------------------------------
CREATE TABLE helpdesk.mantenimientos (
  id SERIAL PRIMARY KEY,
  recurso_id INTEGER NOT NULL REFERENCES helpdesk.recursos(id),
  categoria_id INTEGER NOT NULL REFERENCES helpdesk.categorias_mantenimiento(id),
  tecnico_id INTEGER REFERENCES usuarios.usuarios(id),
  titulo VARCHAR(300) NOT NULL,
  descripcion TEXT,
  prioridad VARCHAR(20) DEFAULT 'Media'
    CHECK (prioridad IN ('Baja', 'Media', 'Alta', 'Crítica')),
  estado VARCHAR(20) DEFAULT 'Pendiente'
    CHECK (estado IN ('Pendiente', 'En Progreso', 'Completado', 'Facturado', 'Cancelado')),
  fecha_solicitud DATE DEFAULT CURRENT_DATE,
  fecha_ejecucion DATE,
  hora_inicio TIME,
  hora_fin TIME,
  costo_mano_obra NUMERIC(12,2) DEFAULT 0,
  costo_repuestos NUMERIC(12,2) DEFAULT 0,
  costo_total NUMERIC(12,2) GENERATED ALWAYS AS (costo_mano_obra + costo_repuestos) STORED,
  venta_item_id INTEGER REFERENCES facturacion.ventas_items(id),
  observaciones TEXT,
  created_at TIMESTAMPTZ DEFAULT now(),
  updated_at TIMESTAMPTZ DEFAULT now()
);

CREATE TRIGGER trg_mantenimientos_updated_at
  BEFORE UPDATE ON helpdesk.mantenimientos
  FOR EACH ROW EXECUTE FUNCTION facturacion.fn_set_updated_at();

-- ------------------------------------------------------------------
-- 4. DETALLES / BITÁCORA DEL MANTENIMIENTO
-- ------------------------------------------------------------------
CREATE TABLE helpdesk.mantenimiento_detalles (
  id SERIAL PRIMARY KEY,
  mantenimiento_id INTEGER NOT NULL REFERENCES helpdesk.mantenimientos(id) ON DELETE CASCADE,
  creado_por INTEGER REFERENCES usuarios.usuarios(id),
  contenido TEXT NOT NULL,
  tipo VARCHAR(20) DEFAULT 'Comentario'
    CHECK (tipo IN ('Comentario', 'Diagnóstico', 'Solución', 'Repuesto', 'Acuerdo')),
  created_at TIMESTAMPTZ DEFAULT now()
);

-- ================================================================
-- SEED: TERCEROS (clientes desde Notion)
-- ================================================================
INSERT INTO generales.terceros (tipo_documento, numero_documento, razon_social) VALUES
  ('NI', '900000001', 'Gestión Calidad'),
  ('NI', '900000002', 'Transglobal de Carga'),
  ('NI', '900000003', 'Montacargas y Transportes'),
  ('NI', '900000004', 'Promatel'),
  ('NI', '900000005', 'Grupo Carpini'),
  ('NI', '900000006', 'Símbolo'),
  ('NI', '900000007', 'Bekko'),
  ('NI', '900000008', 'M2 Contable'),
  ('NI', '900000009', 'Ankaras'),
  ('NI', '900000010', 'Agregados Antioquia'),
  ('NI', '900000011', 'Tysi'),
  ('NI', '900000012', 'Serfletar'),
  ('NI', '900000013', 'Express Labels'),
  ('NI', '900000014', 'AMUC')
ON CONFLICT (tipo_documento, numero_documento) DO NOTHING;

-- ================================================================
-- SEED: RECURSOS desde Notion
-- ================================================================
DO $$
DECLARE
  v_gestion_calidad   INT := (SELECT id FROM generales.terceros WHERE numero_documento = '900000001');
  v_transglobal       INT := (SELECT id FROM generales.terceros WHERE numero_documento = '900000002');
  v_montacargas       INT := (SELECT id FROM generales.terceros WHERE numero_documento = '900000003');
  v_promatel          INT := (SELECT id FROM generales.terceros WHERE numero_documento = '900000004');
  v_grupo_carpini     INT := (SELECT id FROM generales.terceros WHERE numero_documento = '900000005');
  v_simbolo           INT := (SELECT id FROM generales.terceros WHERE numero_documento = '900000006');
  v_bekko             INT := (SELECT id FROM generales.terceros WHERE numero_documento = '900000007');
  v_m2_contable       INT := (SELECT id FROM generales.terceros WHERE numero_documento = '900000008');
  v_ankaras           INT := (SELECT id FROM generales.terceros WHERE numero_documento = '900000009');
BEGIN

  -- Gestión Calidad
  INSERT INTO helpdesk.recursos (cliente_id, nombre, tipo, marca, modelo, serial, descripcion) VALUES
    (v_gestion_calidad, 'Lenovo Andres Cortez',   'Computador', 'Lenovo', 'IdeaPad 3 15IRH10', NULL,       NULL),
    (v_gestion_calidad, 'Lenovo Subey Tatiana',   'Computador', 'Lenovo', 'IdeaPad Slim 3 15IRH10', 'PF68N6RS', NULL),
    (v_gestion_calidad, 'Lenovo Shirley',         'Computador', 'Lenovo', 'IdeaPad 3 15IIL05', 'PF28BJH4',  NULL),
    (v_gestion_calidad, 'HP 14 - Leidy Rodriguez','Computador', 'HP',     'HP 14',              NULL,       NULL),
    (v_gestion_calidad, 'Lenovo Thinkbook Sergio','Computador', 'Lenovo','Thinkbook',          'LR0EYTBH', NULL),
    (v_gestion_calidad, 'Lenovo ideapad 3 - Cindy Betancur','Computador','Lenovo','IdeaPad 3','PF3TE30J', NULL),
    (v_gestion_calidad, 'Lenovo S145 - Yazmin',   'Computador', 'Lenovo', 'S145',               'PF32XNZ3', NULL),
    (v_gestion_calidad, 'Lenovo IdeaPad 3 - Subey','Computador','Lenovo','IdeaPad 3',           'PF369BYV', NULL);

  -- Transglobal de Carga
  INSERT INTO helpdesk.recursos (cliente_id, nombre, tipo, marca, modelo, serial, descripcion) VALUES
    (v_transglobal, 'Veronica Gestion Calidad',   'Computador', NULL,     NULL,                  NULL,       NULL),
    (v_transglobal, 'PC08 - Seguridad',           'Computador', 'DELL',   'Vostro 3458',         '20Z8VF2',  NULL);

  -- Montacargas y Transportes
  INSERT INTO helpdesk.recursos (cliente_id, nombre, tipo, marca, modelo, serial, descripcion) VALUES
    (v_montacargas, 'PC15 - Logistica2',             'Computador', 'DELL',         'Vostro 14 3000',       '3WC9RM3',     NULL),
    (v_montacargas, 'PC18 - Logistica1',             'Computador', 'ASUS',         'VivoBook X409DA_M409DA','L9N0CV059128376', NULL),
    (v_montacargas, 'PC04 - Gerencia Administrativa','Computador', 'HP',           NULL,                    'CND31328D8',  'PC02 - Portatil HP - Johan'),
    (v_montacargas, 'HP Logistica4',                 'Computador', 'HP',           '245 G9',                '5CG4074Y5F',  NULL),
    (v_montacargas, 'PC Logistica3',                 'Computador', 'HP',           '245G10',                '5CG438064',   NULL),
    (v_montacargas, 'PC17 - Coordinador Mantenimiento','Computador','HP',          NULL,                    '5CD2403831',  'PC17 - Portatil HP - Julian Vergara'),
    (v_montacargas, 'PC016 - Compras',               'Computador', NULL,           NULL,                    '5CG21721CN',  NULL);

  -- Promatel
  INSERT INTO helpdesk.recursos (cliente_id, nombre, tipo, marca, modelo, serial, descripcion) VALUES
    (v_promatel, 'PC Sodimac',          'Computador', NULL,    NULL,                   NULL,           'CPU Facturación Home Center'),
    (v_promatel, 'Portátil HP (Cartera)','Computador','HP',    '245 G8',               '5CG1320LKW',   NULL),
    (v_promatel, 'HP AIO Cartera',      'Computador', 'HP',   'AIO 22-DF0007LA',      '8CC1190PNZ',   NULL),
    (v_promatel, 'Tesorería PC',        'Computador', NULL,    NULL,                   NULL,           NULL),
    (v_promatel, 'Hosting Promatel',    'Hosting',    NULL,    NULL,                   NULL,           'Hosting página web');

  -- Grupo Carpini
  INSERT INTO helpdesk.recursos (cliente_id, nombre, tipo, marca, modelo, serial, descripcion) VALUES
    (v_grupo_carpini, 'HP AIO AuxContable','Computador','HP', 'AIO 24-F013LA',       '8CC92326S8',   NULL),
    (v_grupo_carpini, 'Construcción 4',    'Computador',NULL, NULL,                   NULL,           NULL),
    (v_grupo_carpini, 'Comercial 2',       'Computador',NULL, NULL,                   NULL,           NULL),
    (v_grupo_carpini, 'Construcción 2',    'Computador',NULL, NULL,                   NULL,           NULL);

  -- Símbolo
  INSERT INTO helpdesk.recursos (cliente_id, nombre, tipo, marca, modelo, serial, descripcion) VALUES
    (v_simbolo, 'Access Point TP Link',   'Red',      'TP-Link', NULL,   NULL,            'SSID: Simbolo 5G'),
    (v_simbolo, 'HP Juan Diego',          'Computador','HP',      NULL,  NULL,            NULL),
    (v_simbolo, 'ASUS X543UA - Yuliana Rua','Computador','ASUS','X543UA', 'MAN0CX23J75443D', NULL),
    (v_simbolo, 'Computador 1',           'Computador',NULL,      NULL,  NULL,            NULL),
    (v_simbolo, 'Asus JuanFdo',           'Computador','ASUS',    NULL, 'L8N0LP01F492334', NULL),
    (v_simbolo, 'Acer A514',             'Computador','Acer',    'A514', NULL,            NULL);

  -- Bekko
  INSERT INTO helpdesk.recursos (cliente_id, nombre, tipo, marca, modelo, serial, descripcion) VALUES
    (v_bekko, 'ASUS Vivobook 14', 'Computador', 'ASUS', 'Vivobook 14', 'M1N0CX023456012', NULL);

  -- M2 Contable
  INSERT INTO helpdesk.recursos (cliente_id, nombre, tipo, serial, descripcion) VALUES
    (v_m2_contable, 'Office 365 personal', 'Office 365', NULL, 'Suscripción anual');

  -- Ankaras
  INSERT INTO helpdesk.recursos (cliente_id, nombre, tipo, marca, modelo, serial) VALUES
    (v_ankaras, 'ASUS X415', 'Computador', 'ASUS', 'X415', 'R2N0CV09X683088', NULL);

END $$;
