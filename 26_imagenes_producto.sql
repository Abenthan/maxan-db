-- Migración: Tabla inventario.imagenes para fotos de productos
-- Ejecutar en BD existentes que ya tengan el schema inventario

CREATE TABLE IF NOT EXISTS inventario.imagenes (
    id            SERIAL PRIMARY KEY,
    producto_id   INTEGER NOT NULL REFERENCES inventario.productos(id) ON DELETE CASCADE,
    url           TEXT NOT NULL,
    es_principal  BOOLEAN NOT NULL DEFAULT FALSE,
    orden         INTEGER NOT NULL DEFAULT 0,
    created_at    TIMESTAMPTZ NOT NULL DEFAULT now()
);

CREATE INDEX IF NOT EXISTS idx_imagenes_producto ON inventario.imagenes(producto_id);

-- Solo una imagen principal por producto
CREATE UNIQUE INDEX IF NOT EXISTS uq_imagenes_principal
    ON inventario.imagenes(producto_id)
    WHERE es_principal = TRUE;
