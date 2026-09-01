-- ============================================================
-- maxan-db — seeds/03_roles_permisos.sql
-- Asignación de permisos a roles (datos maestros).
-- Idempotente y resuelto por clave natural (nombre de rol + codigo
-- de permiso), de modo que no depende de IDs en producción.
-- Ordenado por permiso para que un mismo rol quede agrupado.
-- Generado desde el dump real (usuarios.roles_permisos).
-- ============================================================

-- Administrador
INSERT INTO usuarios.roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM usuarios.roles r
JOIN usuarios.permisos p ON p.codigo IN (
    'dashboard.ver','facturas.ver','facturas.crear','ventas.ver','ventas.crear',
    'productos.ver','productos.gestionar','gastos.ver','gastos.gestionar',
    'compras.ver','compras.crear','inventario.ver','inventario.gestionar',
    'cartera.ver','cartera.gestionar','terceros.ver','terceros.gestionar',
    'utilidad.ver','usuarios.gestionar','helpdesk.ver','helpdesk.gestionar',
    'helpdesk.casos.ver','helpdesk.casos.gestionar'
)
WHERE r.nombre = 'Administrador'
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- Operador
INSERT INTO usuarios.roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM usuarios.roles r
JOIN usuarios.permisos p ON p.codigo IN (
    'dashboard.ver','facturas.ver','facturas.crear','ventas.ver','ventas.crear',
    'productos.ver','productos.gestionar','gastos.ver','gastos.gestionar',
    'compras.ver','compras.crear','inventario.ver','inventario.gestionar',
    'cartera.ver','cartera.gestionar','terceros.ver','terceros.gestionar',
    'utilidad.ver','helpdesk.ver','helpdesk.gestionar',
    'helpdesk.casos.ver','helpdesk.casos.gestionar'
)
WHERE r.nombre = 'Operador'
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- Consultor
INSERT INTO usuarios.roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM usuarios.roles r
JOIN usuarios.permisos p ON p.codigo IN (
    'dashboard.ver','facturas.ver','ventas.ver','productos.ver','gastos.ver',
    'compras.ver','inventario.ver','cartera.ver','terceros.ver','utilidad.ver',
    'helpdesk.ver','helpdesk.casos.ver'
)
WHERE r.nombre = 'Consultor'
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- Tecnico
INSERT INTO usuarios.roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM usuarios.roles r
JOIN usuarios.permisos p ON p.codigo IN ('helpdesk.ver', 'helpdesk.gestionar')
WHERE r.nombre = 'Tecnico'
ON CONFLICT (rol_id, permiso_id) DO NOTHING;

-- Cliente Tienda
INSERT INTO usuarios.roles_permisos (rol_id, permiso_id)
SELECT r.id, p.id
FROM usuarios.roles r
JOIN usuarios.permisos p ON p.codigo IN ('tienda.perfil', 'tienda.pedidos')
WHERE r.nombre = 'Cliente Tienda'
ON CONFLICT (rol_id, permiso_id) DO NOTHING;