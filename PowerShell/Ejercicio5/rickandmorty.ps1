#!/usr/bin/env pwsh

<#
.SYNOPSIS
    Buscador de información de personajes de la serie Rick and Morty

.DESCRIPTION
    Consulta información de personajes de Rick and Morty utilizando la API de Rick and Morty.
    Almacena los resultados en un archivo cache del cual puede ser eliminado.
    La busqueda se puede realizar por nombre o/y id del personaje, y muestra información.

.PARAMETER nombre
        Nombre(s) de los países a buscar. Múltiples nombres se separan por comas.

.PARAMETER id
        ID(s) de los países a buscar. Múltiples IDs se separan por comas.

.PARAMETER clear
    Elimina el archivo de cache si existe.

.PARAMETER help
    Muestra esta ayuda y sale.

.EXAMPLE
     ./rickandmorty.ps1 -id 1,2 -nombre rick, morty

#>

# EJERCICIO 5
# - Santiago Manghi Scheck


Param(
    [Parameter(Mandatory=$false, ValueFromRemainingArguments=$true)] [string[]]$nombre,
    [Parameter(Mandatory=$false)] [string[]]$id,
    [Parameter(Mandatory=$false)] [switch]$clear,
    [Parameter(Mandatory=$false)] [switch]$help
)

# -----------------------------<FUNCIONES>-----------------------------


function guardarCache {
    # Cargar cache existente o crear nuevo
        param($cacheHashtable)
        $cacheHashtable | ConvertTo-Json -Depth 10 | Set-Content $archivoCache -Encoding UTF8
    
}


function consultarCache {
    if (Test-Path $archivoCache) {
        try {
            $contenido = Get-Content $archivoCache -Raw | ConvertFrom-Json -AsHashtable
            if ($contenido) { return $contenido }
        } catch { }
    }
    return @{}
}

function mostrarPersonaje {
    param($pj)
    Write-Host "Character info:" -ForegroundColor Cyan
    Write-Host "Id: $($pj.id)"
    Write-Host "Name: $($pj.name)"
    Write-Host "Status: $($pj.status)"
    Write-Host "Species: $($pj.species)"
    Write-Host "Gender: $($pj.gender)"
    Write-Host "Origin: $($pj.origin.name)"
    Write-Host "Location: $($pj.location.name)"
    Write-Host "Episodes: $($pj.episode.Count)"
    Write-Host "-------------------------"
}

function procesarBusqueda {
    param([string]$claveCache, [string]$url)

    if ($cache.ContainsKey($claveCache)) {
        Write-Host "Obteniendo datos desde CACHÉ para: $claveCache" -ForegroundColor DarkGray
        $datos = $cache[$claveCache]
    } else {
        try {
            $datos = Invoke-RestMethod -Uri $url -Method Get -ErrorAction Stop
            # Guardamos en caché
            $cache[$claveCache] = $datos
            guardarCache $cache
        } catch {
            Write-Host "Error: No se encontraron resultados o hubo un fallo en la API para la consulta '$claveCache'." -ForegroundColor Red
            return
        }
    }

    # La API devuelve una lista en 'results'
    if ($datos.results) {
        foreach ($pj in $datos.results) {
            mostrarPersonaje $pj
            $script:personajesEncontrados++
        }
    } else {
        # Es un solo personaje (búsqueda por ID)
        mostrarPersonaje $datos
        $script:personajesEncontrados++
    }
}

# -----------------------------<PROGRAMA PRINCIPAL>-----------------------------

if ($help) {
    Get-Help $MyInvocation.MyCommand.Path -Full
    exit 0
}

$archivoCache = "archivo_cache.json"

# Eliminar el archivo de cache si se especifica el parámetro -clear
if ($clear) {
    if ($nombre -or $id) {
        Write-Host "Error: No se puede utilizar -clear junto con los parámetros -id o -nombre." -ForegroundColor Red
        exit 1
    }
    if (Test-Path $archivoCache) {
        Remove-Item $archivoCache
        Write-Host "Caché limpiado exitosamente." -ForegroundColor Green
    } else {
        Write-Host "No hay archivo de caché para limpiar." -ForegroundColor Yellow
    }
    exit 0
}

# Crear archivo de caché si no existe
if (-not (Test-Path $archivoCache)) {
    "{}" | Set-Content $archivoCache -Encoding UTF8
}

# Validaciones
if (-not $nombre -and -not $id) {
    Write-Host "Error: Debe ingresar al menos un parámetro de búsqueda (-id o -nombre)." -ForegroundColor Red
    exit 1
}

$cache = consultarCache
$nombresPorcesados = 0

try {
    if ($id) {
    $ids = ($id -join ',') -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    foreach ($i in $ids) {
        $url = "https://rickandmortyapi.com/api/character/$i"
        procesarBusqueda -claveCache "id $i" -url $url
    }
    }

    if ($nombre) {
    $nombres = ($nombre -join ',') -split ',' | ForEach-Object { $_.Trim() } | Where-Object { $_ -ne "" }
    foreach ($n in $nombres) {
        # Escapar espacios y caracteres para la URL
        $nombreEncoded = [uri]::EscapeDataString($n)
        $url = "https://rickandmortyapi.com/api/character/?name=$nombreEncoded"
        procesarBusqueda -claveCache "name $n" -url $url
    }
    }
} catch {
    Write-Host "Error inesperado: $($_.Exception.Message)" -ForegroundColor Red
    exit 1
}

# Determinar código de salida basado en si se procesó al menos un personaje exitosamente
if ($nombresProcesados -gt 0) {
    exit 0
} else {
    exit 1
}