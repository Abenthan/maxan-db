# maxan-db — Decisión de diseño

## Contexto

El ecosistema Maxan comparte **una sola base de datos PostgreSQL** dev y prod. Los
proyectos `maxan-erp`, `maxan-auth` y `maxan-tienda` dependen de ese mismo cluster. Antes,
el esquema vivía dentro del monolito de `maxan-erp` (`db/init/01_schema.sql`), lo que
hacía que cambios en un proyecto pudieran romper la BD de los otros y que no hubiera una
única fuente de verdad.

## Decisiones

### 1. Repositorio dedicado `maxan-db` como única fuente de verdad
El esquema de la BD compartida se gobierna aquí. Ningún proyecto aplica SQL a la BD
fuera de `init/` + `seeds/` de este repositorio.

### 2. El esquema se deriva de un backup REAL, no del monolito
`backups/dump-maxan_erp-*.sql` es un volcado `pg_dump -Fc` (binario, custom, con datos)
tomado de la BD real. El `init/` se genera desde ese dump con `pg_restore --schema-only`,
de modo que es la foto verdadera del modelo en producción, no una reconstrucción a mano.

### 3. Compatibilidad con PostgreSQL 16
El dump lo produce `pg_dump` 17 (formato 1.16). El motor de la BD compartida es
PostgreSQL 16. `tools/build_init.ps1` limpia los metadatos de pg_dump 17 que PG16 no
entiende (`\restrict`/`\unrestrict`, `SET transaction_timeout`) y reensambla el init en
orden compatible.

### 4. Los ciclos entre schemas se resuelven con dos archivos al final
Las FKs y funciones cruzan schemas:
- `facturacion.vw_utilidad_items` lee `inventario.salidas` y `gastos.gastos`
- `inventario.fn_crear_entrada()` inserta en `inventario.entradas`
- `cartera.fn_actualizar_saldo()` actualiza `facturacion.ventas`
- FKs cruzadas: facturacion→inventario, inventario→gastos, gastos→facturacion, etc.

Para no fallar al crear:

```
00_core  →  schemas + 4 funciones compartidas
01..08   →  objetos locales por schema
09       →  schema tienda
90       →  TODAS las vistas  (dependen de 01..08 + 09)
99       →  TODAS las FKs cross-schema  (rompe los ciclos)
```

### 5. Dueños de esquema por servicio
- **ERP** (`maxan-erp`): es el dueño de `usuarios`, `generales`, `facturacion`, `compras`,
  `inventario`, `gastos`, `cartera`, `helpdesk`.
- **Auth (`maxan-auth`)**: usa `usuarios` (identidad, `sesiones`). No crea schema propio.
- **Tienda (`maxan-tienda`)**: usa `usuarios` (identidad) e `inventario` (catálogo);
  crea su propio schema `tienda` (catálogo de venta, cotizaciones). No modifica los del ERP.

Regla de encaje: **un schema lo modifica solo su dueño.** Tienda nunca toca `inventario`
más que en SELECT; solo crea/administra `tienda.*`.

## Alternativas descartadas

- **Copiar el esquema en cada repositorio**: duplicación y desync; es esto mismo lo que
  se quiere evitar.
- **Usar el monolito `maxan-erp/db/init/...` como fuente**: mezcla CREATE TABLE +
  migraciones históricas + seeds y no refleja el modelo real. Queda `legacy/` por referencia.

## TBD / próximos pasos

- `seeds/` (datos maestros: roles, permisos, categorías, medios de pago, áreas de
  helpdesk …) extraídos de los bloques COPY del dump.
- `legacy/` (archivar `maxan-erp/db/init/01_schema.sql`).
- Integrar el mount de `init/` en `maxan-erp/docker-compose.dev.yml`.