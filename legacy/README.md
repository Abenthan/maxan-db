# legacy/ — Esquema histórico del monolito ERP

Esquema antiguo extraído de `maxan-erp/db/` (el mono: mezcla de `CREATE TABLE` +
migraciones históricas + seeds), archivado aquí como **referencia** y para trazabilidad
de cambios aplicados antes de la centralización.

> **NO es la fuente de verdad.** El esquema canónico y regenerable está en `../init/`.
> Estos archivos documentan cómo evolucionó el modelo en `maxan-erp` (carpeta hoy
> redundante). No se ejecutan contra la BD compartida.

Contenido:
- `init/01_schema.sql` — esquema monolito original (15xx líneas).
- `*.sql` numerados — migraciones históricas (02…26): compras, gastos, inventario,
  cartera, helpdesk, módulo usuarios, vistas, triggers, etc.
- `migrar_*.sql` y `fix_*.sql` — scripts puntuales (terceros, contactos, producción).

## Origen

Copiado verbatim de `D:\Desarrollos\maxan-erp\db\` al consolidar el modelo de datos en
`maxan-db` como única fuente de verdad compartida (ERP + Auth + Tienda).