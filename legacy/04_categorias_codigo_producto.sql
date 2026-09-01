-- =====================================================================
-- MIGRACIÓN: Categorias de productos + codigo_producto en gastos
-- =====================================================================

CREATE TABLE IF NOT EXISTS inventario.categorias (
    id SERIAL PRIMARY KEY,
    nombre VARCHAR(100) NOT NULL UNIQUE,
    created_at TIMESTAMP DEFAULT now()
);

ALTER TABLE gastos.gastos ADD COLUMN codigo_producto VARCHAR(50);
