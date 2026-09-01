# maxan-db

Esquema canónico de la **base de datos PostgreSQL compartida** del ecosistema Maxan
(ERP, Auth/SSO y Tienda). Todos los servicios usan **una sola BD**; este repositorio es
la **única fuente de verdad** de su modelo de datos. Evita que un proyecto rompa la BD de
los otros.

> La fuente de verdad es este repositorio. Nada debe aplicarse a la BD fuera de
> `init/` + `seeds/`. El esquema se **deriva de un backup real** (`backups/`), no del
> monolito `maxan-erp/` (archivado en `legacy/`).

## Estructura

```
maxan-db/
├── init/                # Scripts aplicados automáticamente por PostgreSQL (docker-entrypoint-initdb.d)
│   ├── 00_core.sql      #   CREATE SCHEMA + 4 funciones PL/pgSQL compartidas
│   ├── 01_usuarios.sql  # … 08_helpdesk.sql   objetos locales por schema
│   ├── 09_tienda.sql    #   schema tienda (catálogo/cotizaciones)
│   ├── 90_vistas.sql    #   todas las vistas (cross-schema)
│   └── 99_fk_cross.sql  #   FKs que apuntan a otro schema (rompe ciclos)
├── seeds/               # Datos maestros idempotentes (permisos, roles, catálogos, helpdesk)
├── backups/             # Dumps pg_dump que sirven de baseline (regenerables, sin versionar)
├── legacy/              # Esquema monolito antiguo de maxan-erp (solo referencia, no ejecutar)
├── design.md            # Decisión de diseño y reparto de esquemas por servicio
└── tools/build_init.ps1 # Genera init/ desde backups/ (pg_restore 17, compatible PG16)
```

## Cómo se aplica

Los archivos de `init/` se montan como `/docker-entrypoint-initdb.d` del contenedor de
PostgreSQL; el motor los ejecuta en orden alfabético sobre una BD nueva. En desarrollo
la misma imagen arranca desde cero (p.ej. `docker compose down -v && up`).

```
00_core  →  01..09 por schema  →  90_vistas  →  99_fk_cross
```

- **00_core** crea los 9 schemas y las funciones PL/pgSQL que comparten varios esquemas
  (`facturacion.fn_set_updated_at()` se usa en los triggers de todos).
- **01..08** definen solo objetos locales (tablas, secuencias, defaults, constraints
  que no cruzan schema, índices, triggers y FKs locales).
- **09_tienda** (schema `tienda`) proviene de `maxan-tienda`; no está en el dump porque
  aún no se ha aplicado a la BD.
- **90_vistas** se ejecuta al final porque las vistas cruzan varios schemas.
- **99_fk_cross** se ejecuta al final para no fallar por los ciclos entre esquemas
  (facturacion ↔ inventario ↔ gastos).

## Compatibilidad

- Generado con `pg_dump`/`pg_restore` **17** desde una BD fuente PostgreSQL **16.13**.
- Los `init/*.sql` son compatibles con **PostgreSQL 16** (el motor de la BD compartida).
- El dump en `backups/` es **pg_dump custom `-Fc` (binario) con datos**; para leerlo en
  un contenedor también vale **postgres:18-alpine** (elige el más nuevo). 
  El `init/` NO lleva datos (solo estructura) — los seeds van en `seeds/`.

## Reparto de esquemas por servicio

| Schema        | Dueño principal      | También usado por |
|---------------|----------------------|-------------------|
| `usuarios`    | ERP + Auth           | Tienda (identidad) |
| `generales`   | ERP                  | —                 |
| `facturacion` | ERP                  | Cartera (vistas/fn) |
| `compras`     | ERP                  | Gastos            |
| `inventario`  | ERP                  | Tienda (catálogo) |
| `gastos`      | ERP                  | Inventario (entradas) |
| `cartera`     | ERP                  | —                 |
| `helpdesk`    | ERP                  | —                 |
| `tienda`      | Tienda               | —                 |

## Integración de proyectos

- **ERP** `maxan-erp/docker-compose.dev.yml` monta `./db/init` → apuntar a `maxan-db/init`.
- **Auth** `maxan-auth` y **Tienda** `maxan-tienda` ya no traen su `db/` propio: comparten
  el de aquí.

## Intención de `legacy/`

`maxan-erp/db/init/01_schema.sql` (monolito con migraciones históricas + seeds) se archiva
aquí bajo `legacy/` como referencia, pero **no** es fuente del `init/` nuevo.

## Commands

```bash
# Regenerar init/ desde backups/ (necesita pg_restore 17 + postgres 18/16 para el dump)
powershell -ExecutionPolicy Bypass -File tools/build_init.ps1
```

(En el repositorio Windows, los scripts ps1 se guardan con BOM UTF-8 para que PowerShell 5.1
no los lea como ANSI.)