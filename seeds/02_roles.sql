-- ============================================================
-- maxan-db — seeds/02_roles.sql
-- Roles del sistema (datos maestros).
-- Idempotente: se puede ejecutar varias veces sin error.
-- Generado desde el dump real (usuarios.roles).
-- ============================================================

INSERT INTO usuarios.roles (id, nombre, descripcion)
VALUES
    (1, 'Administrador',  'Acceso total al sistema'),
    (2, 'Operador',       'Puede consultar, crear y editar registros de negocio'),
    (3, 'Consultor',      'Solo consulta de datos'),
    (4, 'Tecnico',        'Soporte tecnico'),
    (5, 'Cliente Tienda', 'Cliente registrado de la tienda web')
ON CONFLICT (nombre) DO NOTHING;