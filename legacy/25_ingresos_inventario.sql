-- ---------------------------------------------------------------------
-- 25. Ingresos manuales de inventario (stock inicial, ajustes, otros)
-- Permite alimentar inventario sin pasar por una compra ni un gasto.
-- ---------------------------------------------------------------------

-- El gasto ya no es obligatorio: una entrada puede ser un ingreso manual
ALTER TABLE inventario.entradas ALTER COLUMN gasto_id DROP NOT NULL;

-- Origen del ingreso: 'gasto' (compras/gastos) o manual: 'inicial', 'ajuste', 'otro'
ALTER TABLE inventario.entradas ADD COLUMN IF NOT EXISTS origen VARCHAR(20) NOT NULL DEFAULT 'gasto';

-- Referencia/observación opcional (ej: "Stock inicial 2026", "Ajuste por conteo")
ALTER TABLE inventario.entradas ADD COLUMN IF NOT EXISTS referencia TEXT;