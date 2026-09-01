# ============================================================
# maxan-db — build_init.ps1
# Ensambla init/*.sql a partir de los dumps por schema generados
# con pg_restore 17 (--schema-only -n <schema> --no-owner --no-privileges).
#
# Transformaciones:
#   - Quita metadatos de pg_dump 17 incompatibles con PostgreSQL 16
#     (\restrict/\unrestrict, SET transaction_timeout, cabecera del dump).
#   - Añade CREATE SCHEMA IF NOT EXISTS para cada schema.
#   - Mueve las 4 funciones PL/pgSQL a 00_core.sql (las comparten todos
#     los schemas: facturacion.fn_set_updated_at, inventario.fn_crear_entrada,
#     gastos.fn_set_clasificacion, cartera.fn_actualizar_saldo).
#   - Mueve TODAS las vistas a 90_vistas.sql (referencian varias schemas).
#   - Mueve TODAS las FKs que referencian otro schema a 99_fk_cross.sql,
#     rompiendo los ciclos facturacion<->inventario<->gastos.
#   - El resto (tablas, secuencias, defaults, constraints locales, índices,
#     triggers, FKs locales) queda en su archivo por schema en el orden
#     original de pg_dump.
#
# Orden final de init/ (docker-entrypoint-initdb.d los ejecuta alfabético):
#   00_core.sql   schemas + funciones compartidas
#   01_usuarios.sql    08_helpdesk.sql   objetos locales por schema
#   09_tienda.sql       schema tienda (desde maxan-tienda/db/01_tienda.sql)
#   90_vistas.sql       todas las vistas
#   99_fk_cross.sql     todas las FKs cross-schema
# ============================================================

param(
    [string]$SchemasDir = 'C:\Users\Usuario\AppData\Local\Temp\opencode\maxan-db-work\schemas',
    [string]$InitDir    = 'D:\Desarrollos\maxan-db\init'
)

$ErrorActionPreference = 'Stop'

$schemas = @(
    @{ file = '01_usuarios.sql';  name = 'usuarios' },
    @{ file = '02_generales.sql'; name = 'generales' },
    @{ file = '03_compras.sql';   name = 'compras' },
    @{ file = '04_facturacion.sql'; name = 'facturacion' },
    @{ file = '05_inventario.sql'; name = 'inventario' },
    @{ file = '06_gastos.sql';    name = 'gastos' },
    @{ file = '07_cartera.sql';   name = 'cartera' },
    @{ file = '08_helpdesk.sql';  name = 'helpdesk' }
)

$sqlSchemas = @('usuarios','generales','compras','facturacion','inventario','gastos','cartera','helpdesk','tienda')

$utf8NoBom = New-Object System.Text.UTF8Encoding($false)

function Add-Silently([System.Text.StringBuilder]$sb, [string]$text) {
    [void]$sb.AppendLine($text)
}
function Append-Text([System.Text.StringBuilder]$sb, [string]$text) {
    [void]$sb.Append($text)
}

# Cabecera estándar compatible con PG16 para cada archivo SQL.
$header = @'
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
'@

# --- Extraer y clasificar un bloque a partir del match base ---
function ConvertFrom-DumpBlock([string]$body, [System.Text.RegularExpressions.Match]$m, [string]$schemaName,
                               [System.Text.StringBuilder]$coreSb, [System.Text.StringBuilder]$vistaSb, [System.Text.StringBuilder]$crossSb) {
    $kw = $m.Groups[1].Value
    $sub = $body.Substring($m.Index)
    # Cabeza normalizada: 2-3 tokens que determinan el tipo de bloque.
    $lead = $sub.TrimStart()
    $head = ''
    if ($lead -match '^CREATE (FUNCTION|VIEW|TABLE|SEQUENCE|INDEX|TRIGGER)'             ) { $head = 'CREATE ' + $Matches[1] }
    elseif ($lead -match '^ALTER SEQUENCE\s+\S+\s+OWNED BY'                              ) { $head = 'ALTER SEQUENCE OWNED BY' }
    elseif ($lead -match '^ALTER TABLE ONLY\s+\S+\s+ALTER COLUMN\s+\S+\s+SET DEFAULT'   ) { $head = 'ALTER TABLE ONLY SET DEFAULT' }
    elseif ($lead -match '^ALTER TABLE ONLY\s+\S+\s+ADD CONSTRAINT'                      ) { $head = 'ALTER TABLE ONLY ADD CONSTRAINT' }
    else { $head = 'UNKNOWN' }

    if ($head -eq 'UNKNOWN') {
        throw "Tipo de bloque no reconocido (schema $schemaName): $($lead.Substring(0, [Math]::Min(60, $lead.Length)))"
    }
    $frag = $null
    # Cada regex usa \A (inicio absoluto del substring) para no re-localizar
    # el primer keyword dentro del substring, y (?m) para anclar ^/$ a líneas.
    switch -Regex ($head) {
        '^CREATE FUNCTION' {
            $frag = [regex]::Match($sub, '(?ms)\ACREATE FUNCTION .*?^\$\$;\s*$').Value
        }
        '^CREATE VIEW' {
            $frag = [regex]::Match($sub, '(?s)\ACREATE VIEW .*?;').Value
        }
        '^CREATE TABLE' {
            $frag = [regex]::Match($sub, '(?ms)\ACREATE TABLE .*?^\);').Value
        }
        '^CREATE SEQUENCE' {
            $frag = [regex]::Match($sub, '(?s)\ACREATE SEQUENCE .*?CACHE [0-9]+;').Value
        }
        '^ALTER SEQUENCE' {
            $frag = [regex]::Match($sub, '(?s)\AALTER SEQUENCE \S+ OWNED BY \S+;').Value
        }
        '^ALTER TABLE ONLY SET DEFAULT' {
            $frag = [regex]::Match($sub, '(?s)\AALTER TABLE ONLY \S+ ALTER COLUMN \S+ SET DEFAULT .*?;').Value
        }
        '^ALTER TABLE ONLY ADD CONSTRAINT' {
            $frag = [regex]::Match($sub, '(?s)\AALTER TABLE ONLY \S+\s+ADD CONSTRAINT \S+ .*?;').Value
        }
        '^CREATE INDEX' {
            $frag = [regex]::Match($sub, '(?s)\ACREATE INDEX \S+ ON \S+ USING \w+ \([^;]*\);').Value
        }
        '^CREATE TRIGGER' {
            $frag = [regex]::Match($sub, '(?s)\ACREATE TRIGGER \S+ .*?;').Value
        }
    }
    if (-not $frag) {
        throw "No se pudo extraer bloque empezando con: $head (schema $schemaName)"
    }

    if ($frag -match '(?s)\ACREATE FUNCTION') {
        Add-Silently $coreSb ($frag.TrimEnd())
        Add-Silently $coreSb ''
    } elseif ($frag -match '(?s)\ACREATE VIEW') {
        Add-Silently $vistaSb ($frag.TrimEnd())
        Add-Silently $vistaSb ''
    } elseif ($frag -match '(?is)\AALTER TABLE ONLY .* ADD CONSTRAINT .* FOREIGN KEY') {
        # FK -> local si referencia el mismo schema, si no a 99_fk_cross
        $rm = [regex]::Match($frag, '(?is)\bREFERENCES\s+(\w+)\.(\w+)')
        if ($rm.Success) {
            if ($rm.Groups[1].Value -ne $schemaName) {
                Add-Silently $crossSb ($frag.TrimEnd())
                Add-Silently $crossSb ''
            } else {
                Add-Silently $localSb ($frag.TrimEnd())
            }
        } else {
            Add-Silently $localSb ($frag.TrimEnd())
        }
    } else {
        Add-Silently $localSb ($frag.TrimEnd())
    }
}

# --- Limpiar un dump por schema: header/restrict/trailer + clasificar ---
function ConvertFrom-SchemaDump([string]$path, [string]$schemaName,
                                [System.Text.StringBuilder]$coreSb, [System.Text.StringBuilder]$vistaSb, [System.Text.StringBuilder]$crossSb) {
    $raw = [System.IO.File]::ReadAllText($path, [System.Text.Encoding]::UTF8)
    $lines = $raw -split "`r?`n"

    # El dump generado con pg_restore 17 tiene este esqueleto:
    #   cabecera (-- PostgreSQL database dump, -- Dumped from..., SET ...,
    #            \restrict <token>, SET transaction_timeout) 
    #   Cuerpo: objetos del schema (todo es válido salvo \restrict/
    #           \unrestrict y transaction_timeout)
    #   \unrestrict <token>, -- PostgreSQL database dump complete
    #
    # Estrategia: conservar solo lo que está ENTRE el primer \restrict y el
    # \unrestrict final, quitando las líneas \restrict/\unrestrict y
    # transaction_timeout (incompatibles con PostgreSQL 16).
    $startIdx = -1
    $endIdx = $lines.Count
    for ($i = 0; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -match '^\\restrict\s') { $startIdx = $i; break }
    }
    for ($i = $lines.Count - 1; $i -ge 0; $i--) {
        if ($lines[$i] -match '^\\unrestrict\s') { $endIdx = $i; break }
    }
    if ($startIdx -lt 0) { throw "No se encontro \\restrict en: $path" }

    $keep = New-Object System.Collections.Generic.List[string]
    for ($i = $startIdx + 1; $i -lt $endIdx; $i++) {
        if ($lines[$i] -match '^SET transaction_timeout = 0;') { continue }
        if ($lines[$i] -match '^\\?(?:restrict|unrestrict)\s') { continue }
        $keep.Add($lines[$i])
    }
    $body = ($keep -join "`n") -replace "\r?\n\s*\r?\n\s*$", ''

    # Bucket para FKs/objetos locales de ESTE schema (por orden de pg_dump).
    $script:localSb = New-Object System.Text.StringBuilder

    $patternParts = @(
        'CREATE FUNCTION', 'CREATE VIEW', 'CREATE TABLE', 'CREATE SEQUENCE',
        'ALTER SEQUENCE \S+ OWNED BY',
        'ALTER TABLE ONLY \S+ ALTER COLUMN \S+ SET DEFAULT',
        'ALTER TABLE ONLY \S+\s+ADD CONSTRAINT',
        'CREATE INDEX', 'CREATE TRIGGER'
    )
    $pattern = '(?ms)(?:' + ($patternParts -join '|') + ')'
    $matches = [regex]::Matches($body, $pattern)

    foreach ($m in $matches) {
        ConvertFrom-DumpBlock $body $m $schemaName $coreSb $vistaSb $crossSb
    }
    return $script:localSb.ToString()
}

New-Item -ItemType Directory -Force -Path $InitDir | Out-Null

# Acumuladores globales
$coreSb  = New-Object System.Text.StringBuilder
$vistaSb = New-Object System.Text.StringBuilder
$crossSb = New-Object System.Text.StringBuilder
$script:localSb = New-Object System.Text.StringBuilder

foreach ($item in $schemas) {
    $srcPath = Join-Path $SchemasDir ($item.name + '.sql')
    $cleaned = ConvertFrom-SchemaDump $srcPath $item.name $coreSb $vistaSb $crossSb

    $bodySb = New-Object System.Text.StringBuilder
    Add-Silently $bodySb '-- ============================================================'
    Add-Silently $bodySb "-- maxan-db - $($item.file) (generado por tools/build_init.ps1)"
    Add-Silently $bodySb "-- Objetos locales del schema '$($item.name)': tablas, secuencias,"
    Add-Silently $bodySb '-- defaults, constraints locales, indices, triggers y FKs locales.'
    Add-Silently $bodySb '-- Las FKs que apuntan a otro schema viven en 99_fk_cross.sql'
    Add-Silently $bodySb '-- y las vistas en 90_vistas.sql.'
    Add-Silently $bodySb '-- ============================================================'
    Add-Silently $bodySb ''
    Append-Text $bodySb $header
    Add-Silently $bodySb ''
    Add-Silently $bodySb "CREATE SCHEMA IF NOT EXISTS $($item.name);"
    Add-Silently $bodySb ''
    Append-Text $bodySb ($cleaned.TrimEnd())
    Add-Silently $bodySb ''
    [System.IO.File]::WriteAllText((Join-Path $InitDir $item.file), $bodySb.ToString(), $utf8NoBom)
    Write-Host "ok  $($item.file)"
}

# --- 00_core.sql ---------------------------------------------------------
$coreOut = New-Object System.Text.StringBuilder
Add-Silently $coreOut '-- ============================================================'
Add-Silently $coreOut '-- maxan-db - 00_core.sql (generado por tools/build_init.ps1)'
Add-Silently $coreOut '-- Schemas + funciones PL/pgSQL compartidas por todos los schemas.'
Add-Silently $coreOut '-- Generado desde backups/dump-maxan_erp-*.sql con pg_restore 17.'
Add-Silently $coreOut '-- Compatible con PostgreSQL 16.'
Add-Silently $coreOut '-- Incluir SIEMPRE antes de los archivos 01..99.'
Add-Silently $coreOut '-- ============================================================'
Add-Silently $coreOut ''
Append-Text $coreOut $header
Add-Silently $coreOut ''
Add-Silently $coreOut '-- Schemas del ecosistema Maxan.'
foreach ($s in $sqlSchemas) {
    Add-Silently $coreOut "CREATE SCHEMA IF NOT EXISTS $s;"
}
Add-Silently $coreOut ''
Add-Silently $coreOut '-- ============================================================'
Add-Silently $coreOut '-- Funciones PL/pgSQL compartidas (compilacion diferida a PG):'
Add-Silently $coreOut '--   facturacion.fn_set_updated_at()  - versiona updated_at en todos los schemas'
Add-Silently $coreOut '--   inventario.fn_crear_entrada()    - entrada automatica al clasificar gasto Suministros'
Add-Silently $coreOut '--   gastos.fn_set_clasificacion()   - fuerza clasificacion Suministros si hay producto'
Add-Silently $coreOut '--   cartera.fn_actualizar_saldo()   - recalcula saldo/estado de la venta al pagar'
Add-Silently $coreOut '-- ============================================================'
Add-Silently $coreOut ''
Append-Text $coreOut ($coreSb.ToString().TrimEnd())
Add-Silently $coreOut ''
[System.IO.File]::WriteAllText((Join-Path $InitDir '00_core.sql'), $coreOut.ToString(), $utf8NoBom)
Write-Host 'ok  00_core.sql'

# --- 90_vistas.sql ---------------------------------------------------------
$vOut = New-Object System.Text.StringBuilder
Add-Silently $vOut '-- ============================================================'
Add-Silently $vOut '-- maxan-db - 90_vistas.sql (generado por tools/build_init.ps1)'
Add-Silently $vOut '-- Todas las vistas (referencian tablas de varios schemas;'
Add-Silently $vOut '-- deben crearse al final, cuando existen todas las tablas).'
Add-Silently $vOut '-- ============================================================'
Add-Silently $vOut ''
Append-Text $vOut $header
Add-Silently $vOut ''
Append-Text $vOut ($vistaSb.ToString().TrimEnd())
Add-Silently $vOut ''
[System.IO.File]::WriteAllText((Join-Path $InitDir '90_vistas.sql'), $vOut.ToString(), $utf8NoBom)
Write-Host 'ok  90_vistas.sql'

# --- 99_fk_cross.sql ---------------------------------------------------------
$fOut = New-Object System.Text.StringBuilder
Add-Silently $fOut '-- ============================================================'
Add-Silently $fOut '-- maxan-db - 99_fk_cross.sql (generado por tools/build_init.ps1)'
Add-Silently $fOut '-- FKs que referencian tablas de OTRO schema. Se aplican al final'
Add-Silently $fOut '-- para romper los ciclos facturacion<->inventario<->gastos.'
Add-Silently $fOut '-- ============================================================'
Add-Silently $fOut ''
Append-Text $fOut $header
Add-Silently $fOut ''
Append-Text $fOut ($crossSb.ToString().TrimEnd())
Add-Silently $fOut ''
[System.IO.File]::WriteAllText((Join-Path $InitDir '99_fk_cross.sql'), $fOut.ToString(), $utf8NoBom)
Write-Host 'ok  99_fk_cross.sql'

Write-Host "Listo. init/ -> $InitDir"