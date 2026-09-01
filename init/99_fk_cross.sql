-- ============================================================
-- maxan-db - 99_fk_cross.sql (generado por tools/build_init.ps1)
-- FKs que referencian tablas de OTRO schema. Se aplican al final
-- para romper los ciclos facturacion<->inventario<->gastos.
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
ALTER TABLE ONLY compras.facturas_compra
    ADD CONSTRAINT facturas_compra_proveedor_id_fkey FOREIGN KEY (proveedor_id) REFERENCES generales.terceros(id);

ALTER TABLE ONLY compras.facturas_compra
    ADD CONSTRAINT facturas_compra_receptor_id_fkey FOREIGN KEY (receptor_id) REFERENCES generales.terceros(id);

ALTER TABLE ONLY facturacion.ventas
    ADD CONSTRAINT ventas_emisor_id_fkey FOREIGN KEY (emisor_id) REFERENCES generales.terceros(id);

ALTER TABLE ONLY facturacion.ventas_items
    ADD CONSTRAINT ventas_items_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES inventario.productos(id);

ALTER TABLE ONLY facturacion.ventas
    ADD CONSTRAINT ventas_receptor_id_fkey FOREIGN KEY (receptor_id) REFERENCES generales.terceros(id);

ALTER TABLE ONLY inventario.entradas
    ADD CONSTRAINT entradas_gasto_id_fkey FOREIGN KEY (gasto_id) REFERENCES gastos.gastos(id) ON DELETE CASCADE;

ALTER TABLE ONLY inventario.salidas
    ADD CONSTRAINT salidas_factura_item_id_fkey FOREIGN KEY (factura_item_id) REFERENCES facturacion.ventas_items(id) ON DELETE CASCADE;

ALTER TABLE ONLY gastos.gastos
    ADD CONSTRAINT gastos_factura_compra_id_fkey FOREIGN KEY (factura_compra_id) REFERENCES compras.facturas_compra(id) ON DELETE CASCADE;

ALTER TABLE ONLY gastos.gastos
    ADD CONSTRAINT gastos_producto_id_fkey FOREIGN KEY (producto_id) REFERENCES inventario.productos(id);

ALTER TABLE ONLY gastos.gastos
    ADD CONSTRAINT gastos_proveedor_id_fkey FOREIGN KEY (proveedor_id) REFERENCES generales.terceros(id);

ALTER TABLE ONLY gastos.gastos
    ADD CONSTRAINT gastos_venta_item_id_fkey FOREIGN KEY (venta_item_id) REFERENCES facturacion.ventas_items(id);

ALTER TABLE ONLY cartera.pago_aplicaciones
    ADD CONSTRAINT pago_aplicaciones_venta_id_fkey FOREIGN KEY (venta_id) REFERENCES facturacion.ventas(id) ON DELETE CASCADE;

ALTER TABLE ONLY cartera.pagos
    ADD CONSTRAINT pagos_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES generales.terceros(id);

ALTER TABLE ONLY helpdesk.caso_detalles
    ADD CONSTRAINT caso_detalles_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES usuarios.usuarios(id);

ALTER TABLE ONLY helpdesk.casos
    ADD CONSTRAINT casos_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES generales.terceros(id);

ALTER TABLE ONLY helpdesk.casos
    ADD CONSTRAINT casos_contacto_id_fkey FOREIGN KEY (contacto_id) REFERENCES generales.contactos(id);

ALTER TABLE ONLY helpdesk.casos_contactos
    ADD CONSTRAINT casos_contactos_contacto_id_fkey FOREIGN KEY (contacto_id) REFERENCES generales.contactos(id) ON DELETE CASCADE;

ALTER TABLE ONLY helpdesk.casos
    ADD CONSTRAINT casos_tecnico_id_fkey FOREIGN KEY (tecnico_id) REFERENCES usuarios.usuarios(id);

ALTER TABLE ONLY helpdesk.casos
    ADD CONSTRAINT casos_venta_item_id_fkey FOREIGN KEY (venta_item_id) REFERENCES facturacion.ventas_items(id);

ALTER TABLE ONLY helpdesk.mantenimiento_detalles
    ADD CONSTRAINT mantenimiento_detalles_creado_por_fkey FOREIGN KEY (creado_por) REFERENCES usuarios.usuarios(id);

ALTER TABLE ONLY helpdesk.mantenimientos
    ADD CONSTRAINT mantenimientos_tecnico_id_fkey FOREIGN KEY (tecnico_id) REFERENCES usuarios.usuarios(id);

ALTER TABLE ONLY helpdesk.mantenimientos
    ADD CONSTRAINT mantenimientos_venta_item_id_fkey FOREIGN KEY (venta_item_id) REFERENCES facturacion.ventas_items(id);

ALTER TABLE ONLY helpdesk.recursos
    ADD CONSTRAINT recursos_cliente_id_fkey FOREIGN KEY (cliente_id) REFERENCES generales.terceros(id);
