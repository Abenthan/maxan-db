-- ============================================================
-- maxan-tienda — Migración 01: schema `tienda`
-- Tablas en la BD compartida del ERP (no duplicar datos).
-- El ERP es la única fuente de verdad de productos e inventario;
-- la tienda solo consume y genera cotizaciones.
-- Idempotente: se puede ejecutar varias veces sin error.
-- ============================================================

CREATE SCHEMA IF NOT EXISTS tienda;

-- Precio y visibilidad de venta por producto del ERP.
-- La tienda NO modifica inventario.productos; solo administra su precio/visibilidad.
-- Se gestiona desde el ERP (o vía SQL en el MVP).
CREATE TABLE IF NOT EXISTS tienda.productos_venta (
    id          SERIAL PRIMARY KEY,
    producto_id INT NOT NULL UNIQUE REFERENCES inventario.productos(id) ON DELETE CASCADE,
    precio      NUMERIC(12,2) NOT NULL CHECK (precio >= 0),
    activo      BOOLEAN NOT NULL DEFAULT TRUE,          -- visible en el catálogo
    destacado   BOOLEAN NOT NULL DEFAULT FALSE,
    descripcion TEXT,                                    -- copy de venta (opcional)
    created_at  TIMESTAMPTZ NOT NULL DEFAULT now(),
    updated_at  TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Cotizaciones/pedidos pendientes.
-- El asesor valida precio/disponibilidad y confirma la venta desde el ERP.
CREATE TABLE IF NOT EXISTS tienda.cotizaciones (
    id            SERIAL PRIMARY KEY,
    usuario_id    INTEGER NOT NULL REFERENCES usuarios.usuarios(id) ON DELETE CASCADE,
    estado        TEXT NOT NULL DEFAULT 'pendiente'
                  CHECK (estado IN ('pendiente','confirmada','cancelada')),
    observaciones TEXT,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

-- Items con snapshot (sin FK al ERP: desacoplado de cambios en el catálogo).
CREATE TABLE IF NOT EXISTS tienda.cotizaciones_items (
    id            SERIAL PRIMARY KEY,
    cotizacion_id INTEGER NOT NULL REFERENCES tienda.cotizaciones(id) ON DELETE CASCADE,
    producto_id   INTEGER,                               -- referencia al ERP, sin FK
    codigo        VARCHAR(50) NOT NULL,
    nombre        VARCHAR(255) NOT NULL,
    unidad_medida VARCHAR(10),
    cantidad      NUMERIC(18,6) NOT NULL CHECK (cantidad > 0),
    precio        NUMERIC(12,2) NOT NULL,
    subtotal      NUMERIC(12,2) NOT NULL
);

CREATE INDEX IF NOT EXISTS idx_productos_venta_activo ON tienda.productos_venta(activo);
CREATE INDEX IF NOT EXISTS idx_cotizaciones_usuario ON tienda.cotizaciones(usuario_id);
CREATE INDEX IF NOT EXISTS idx_cotizaciones_items_cotizacion ON tienda.cotizaciones_items(cotizacion_id);
