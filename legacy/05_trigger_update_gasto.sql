-- =====================================================================
-- MIGRACIÓN: Trigger crea/actualiza entrada de inventario también en UPDATE
-- =====================================================================

CREATE OR REPLACE FUNCTION inventario.fn_crear_entrada()
RETURNS TRIGGER AS $$
DECLARE
    v_inventariable BOOLEAN;
    v_entrada_id INT;
BEGIN
    IF NEW.producto_id IS NOT NULL THEN
        SELECT inventariable INTO v_inventariable FROM inventario.productos WHERE id = NEW.producto_id;
        IF v_inventariable THEN
            SELECT id INTO v_entrada_id FROM inventario.entradas WHERE gasto_id = NEW.id;
            IF NOT FOUND THEN
                INSERT INTO inventario.entradas (gasto_id, producto_id, cantidad, cantidad_disponible, costo_unitario, fecha)
                VALUES (NEW.id, NEW.producto_id, NEW.cantidad, NEW.cantidad, NEW.valor_unitario, NEW.fecha);
            ELSE
                UPDATE inventario.entradas
                SET producto_id = NEW.producto_id,
                    cantidad = NEW.cantidad,
                    cantidad_disponible = NEW.cantidad,
                    costo_unitario = NEW.valor_unitario,
                    fecha = NEW.fecha
                WHERE id = v_entrada_id;
            END IF;
        END IF;
    ELSE
        DELETE FROM inventario.entradas WHERE gasto_id = NEW.id;
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_gastos_crear_entrada ON gastos.gastos;

CREATE TRIGGER trg_gastos_crear_entrada
    AFTER INSERT OR UPDATE OF producto_id ON gastos.gastos
    FOR EACH ROW EXECUTE FUNCTION inventario.fn_crear_entrada();
