-- ============================================================
-- maxan-db - 00_core.sql (generado por tools/build_init.ps1)
-- Schemas + funciones PL/pgSQL compartidas por todos los schemas.
-- Generado desde backups/dump-maxan_erp-*.sql con pg_restore 17.
-- Compatible con PostgreSQL 16.
-- Incluir SIEMPRE antes de los archivos 01..99.
-- ============================================================

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

SET default_tablespace = '';

SET default_table_access_method = heap;
-- Schemas del ecosistema Maxan.
CREATE SCHEMA IF NOT EXISTS usuarios;
CREATE SCHEMA IF NOT EXISTS generales;
CREATE SCHEMA IF NOT EXISTS compras;
CREATE SCHEMA IF NOT EXISTS facturacion;
CREATE SCHEMA IF NOT EXISTS inventario;
CREATE SCHEMA IF NOT EXISTS gastos;
CREATE SCHEMA IF NOT EXISTS cartera;
CREATE SCHEMA IF NOT EXISTS helpdesk;
CREATE SCHEMA IF NOT EXISTS tienda;

-- ============================================================
-- Funciones PL/pgSQL compartidas (compilacion diferida a PG):
--   facturacion.fn_set_updated_at()  - versiona updated_at en todos los schemas
--   inventario.fn_crear_entrada()    - entrada automatica al clasificar gasto Suministros
--   gastos.fn_set_clasificacion()   - fuerza clasificacion Suministros si hay producto
--   cartera.fn_actualizar_saldo()   - recalcula saldo/estado de la venta al pagar
-- ============================================================

CREATE FUNCTION facturacion.fn_set_updated_at() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    NEW.updated_at = now();
    RETURN NEW;
END;
$$;

CREATE FUNCTION inventario.fn_crear_entrada() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_inventariable BOOLEAN;
    v_entrada_id INT;
BEGIN
    IF NEW.producto_id IS NOT NULL AND NEW.clasificacion = 'Suministros' THEN
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
$$;

CREATE FUNCTION gastos.fn_set_clasificacion() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
BEGIN
    IF NEW.producto_id IS NOT NULL THEN
        NEW.clasificacion := 'Suministros';
    END IF;
    RETURN NEW;
END;
$$;

CREATE FUNCTION cartera.fn_actualizar_saldo() RETURNS trigger
    LANGUAGE plpgsql
    AS $$
DECLARE
    v_total_pagado      NUMERIC(18,2);
    v_valor_venta       NUMERIC(18,2);
    v_total_retenciones NUMERIC(18,2);
    v_venta_id          INT;
BEGIN
    v_venta_id := COALESCE(NEW.venta_id, OLD.venta_id);

    SELECT v.valor_a_pagar INTO v_valor_venta
    FROM facturacion.ventas v WHERE v.id = v_venta_id;

    SELECT COALESCE(SUM(pa.valor_aplicado), 0) INTO v_total_pagado
    FROM cartera.pago_aplicaciones pa WHERE pa.venta_id = v_venta_id;

    SELECT COALESCE(v.valor_retencion_fuente, 0) INTO v_total_retenciones
    FROM facturacion.ventas v WHERE v.id = v_venta_id;

    UPDATE facturacion.ventas
    SET saldo_pendiente = GREATEST(v_valor_venta - v_total_pagado - v_total_retenciones, 0),
        estado = CASE
            WHEN v_total_pagado + v_total_retenciones >= v_valor_venta THEN 'pagada'
            WHEN v_total_pagado > 0 THEN 'pagada_parcial'
            ELSE 'pendiente_pago'
        END
    WHERE id = v_venta_id
      AND estado NOT IN ('anulada', 'rechazada');

    RETURN COALESCE(NEW, OLD);
END;
$$;
