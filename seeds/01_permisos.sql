-- ============================================================
-- maxan-db — seeds/01_permisos.sql
-- Catálogo de permisos del sistema (datos maestros).
-- Idempotente: se puede ejecutar varias veces sin error.
-- Generado desde el dump real (usuarios.permisos).
-- ============================================================

INSERT INTO usuarios.permisos (id, codigo, nombre, descripcion, modulo)
VALUES
    (1,    'dashboard.ver',            'Ver Dashboard',                         'Puede ver el dashboard principal',              'Dashboard'),
    (2,    'facturas.ver',             'Ver facturas',                          'Puede ver las facturas emitidas',                'Facturación'),
    (3,    'facturas.crear',           'Crear facturas (subir XML)',            'Puede subir o crear facturas',                   'Facturación'),
    (4,    'ventas.ver',               'Ver items de venta',                    'Puede ver los items de venta',                   'Ventas'),
    (5,    'ventas.crear',             'Crear/editar ventas manuales',          'Puede crear y editar ventas manuales',           'Ventas'),
    (6,    'productos.ver',            'Ver catálogo de productos',             'Puede ver el catálogo',                          'Productos'),
    (7,    'productos.gestionar',      'Crear/editar productos',                'Puede crear y editar productos',                 'Productos'),
    (8,    'gastos.ver',               'Ver gastos',                            'Puede ver los gastos',                           'Gastos'),
    (9,    'gastos.gestionar',         'Crear/editar/eliminar gastos',          'Puede administrar gastos',                       'Gastos'),
    (10,   'compras.ver',              'Ver compras',                           'Puede ver las compras',                          'Compras'),
    (11,   'compras.crear',            'Subir XML de compra',                   'Puede registrar compras',                        'Compras'),
    (12,   'inventario.ver',           'Ver stock y movimientos',               'Puede ver el inventario',                        'Inventario'),
    (13,   'inventario.gestionar',     'Consumir inventario',                   'Puede gestionar movimientos de inventario',      'Inventario'),
    (14,   'cartera.ver',              'Ver cartera y pagos',                   'Puede ver cartera y pagos',                      'Cartera'),
    (15,   'cartera.gestionar',        'Registrar/anular pagos',                'Puede registrar y anular pagos',                 'Cartera'),
    (16,   'terceros.ver',             'Ver terceros',                          'Puede ver terceros',                             'Terceros'),
    (17,   'terceros.gestionar',       'Crear/editar/eliminar terceros',        'Puede gestionar terceros',                       'Terceros'),
    (18,   'utilidad.ver',             'Ver reporte de utilidad',               'Puede ver reportes de utilidad',                 'Utilidad'),
    (19,   'usuarios.gestionar',       'Gestionar usuarios, roles y permisos',  'Puede administrar usuarios y roles',             'Administración'),
    (115,  'helpdesk.ver',             'Ver recursos y mantenimientos',         'Puede ver recursos y mantenimientos',            'Helpdesk'),
    (116,  'helpdesk.gestionar',       'Crear/editar recursos y mantenimientos','Puede gestionar recursos y mantenimientos',      'Helpdesk'),
    (516,  'helpdesk.casos.ver',       'Ver casos de soporte',                  'Puede ver casos de soporte',                     'Helpdesk'),
    (517,  'helpdesk.casos.gestionar', 'Crear/editar/cerrar casos de soporte',  'Puede gestionar casos de soporte',               'Helpdesk'),
    (2604, 'tienda.perfil',            'Ver perfil de cliente',                 'Puede ver su perfil de cliente de la tienda',    'Tienda'),
    (2605, 'tienda.pedidos',           'Ver y gestionar pedidos',               'Puede ver y gestionar sus pedidos de la tienda', 'Tienda')
ON CONFLICT (codigo) DO NOTHING;