<#
Integrantes: 
            Chavez, Christian                   94529742    
            ,Nicolas                            11111111    
            ,Fernando                           11111111    
            ,S                                  11111111            
#>

<#
.SYNOPSIS
Script de procesamiento de CSV

.DESCRIPTION
Este script procesa un archivo CSV y realiza operaciones simples de filtros, suma y cuentas sobre los campos del mismo.
Se debe tener en cuenta que: 
• Se puede filtrar un campo por un patrón de texto. Ejemplos: Pais = “Argentina”, Provincia = “San” (filtra tanto Santa Cruz, Santa Fe, San Juan y San Luis). 
• Se puede solicitar la sumatoria de un campo determinado, aplicando o no un filtro previo.
• Se puede solicitar la cantidad de registros, aplicando o no un filtro.

.PARAMETER archivo
Archivo CSV a procesar. 

.PARAMETER filtro
Opcional, Nombre del campo a utilizar para filtrar. 

.PARAMETER buscar
Opcional, requerido si se usó el parámetro filtro. Patrón a buscar en el campo filtro. 

.PARAMETER contar
Operación para Contar registros. 

.PARAMETER sumar
Nombre del campo para la operación de suma. 

.EXAMPLE
.\ejercicio_1.ps1 -archivo "censos.csv" -sumar "Poblacion"

.EXAMPLE
.\ejercicio_1.ps1 -archivo "censos.csv" -contar

.EXAMPLE
.\ejercicio_1.ps1 -archivo "censos.csv" -filtro "Provincia" -buscar "Cordoba" -sumar "Poblacion"

.EXAMPLE
.\ejercicio_1.ps1 -archivo "censos.csv" -filtro "Pais" -buscar "Chile" -contar


.OUTPUTS
Se muestra el resultado por pantalla
#>

########################## Obtencion y control de parametros #########################
[CmdletBinding()]
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript(
        { Test-Path $_ -PathType Leaf },
        ErrorMessage = "Error: El archivo '{0}' no existe o no es un archivo válido."
    )]
    [ValidateScript(
        { (Get-Item $_).Length -gt 0 },
        ErrorMessage = "Error: El archivo '{0}' está vacío."
    )]
    [string]$archivo,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$filtro,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$buscar,

    [Parameter(Mandatory=$false)]
    [switch]$contar,

    [Parameter(Mandatory=$false)]
    [ValidateNotNullOrEmpty()]
    [string]$sumar
)

#validar parametros filtro y busqueda
if ($filtro -and -not $buscar) {
    Write-Host "Error: Si se indica un campo para filtrar, también debe indicar un patrón de búsqueda."
    exit 1 
}

if ($buscar -and -not $filtro) {
    Write-Host "Error: Si se indica un patrón de búsqueda, también debe indicar un campo para filtrar."
    exit 1 
}

#validar parametros sumar y contar
if ($contar -and $sumar) {
    Write-Host "Solo se permite una funcionalidad sumar o contar por ejecución."
    exit 1 
}

if (-not $sumar -and -not $contar) {
    Write-Host "Error: Se debe indicar por lo menos una funcionalidad: contar o sumar."
    exit 1 
}


######################### Funciones #########################
function procesar {
$datos = Import-Csv -Path $archivo

# valido si el CSV tiene solo cabecera y ningún registro
if (-not $datos) {
    Write-Host "Error: El archivo no contiene registros para procesar."
    exit 1 
}

# obtener nombres de columnas, '$columnas' es un vector de strings con el nombre de todas las columnas
$columnas = $datos[0].PSObject.Properties.Name

# validar filtro
if ($filtro -and ($columnas -notcontains $filtro)) {
    Write-Host "Error: El campo '$filtro' no existe en el archivo."
    exit 1 
}

# validar suma
if ($sumar -and ($columnas -notcontains $sumar)) {
    Write-Host "Error: El campo '$sumar' no existe en el archivo."
    exit 1 
}

# valido si tenemos que filtrar por algun campo
if ($filtro) {
    $datosFiltrados = $datos | Where-Object {
        $_.$filtro -like "*$buscar*"
    }
}
else {
    $datosFiltrados = $datos
}

# funcionalidad contar
if ($contar) {
    $resultado = $datosFiltrados.Count

    if ($filtro) {
        Write-Output "La cantidad de registros filtrando por '$filtro=$buscar' es: $resultado"
    }
    else {
        Write-Output "La cantidad de registros es: $resultado"
    }
}

# funcionalidad sumar
if ($sumar) {
    $sumaTotal = 0

    foreach ($registro in $datosFiltrados) {
        $valor = $registro.$sumar

        if ($valor -notmatch '^-?\d+(\.\d+)?$') { #expresion regular para validar que el campo sea numerico (postivo, negativo, entero o decimal)
            Write-Host "Error: El campo '$sumar' contiene valores no numéricos."
            exit 1 
        }

        $sumaTotal += [double]$valor
    }

    if ($filtro) {
        Write-Output "La suma del campo '$sumar' filtrando por '$filtro=$buscar' es: $sumaTotal"
    }
    else {
        Write-Output "La suma del campo '$sumar' es: $sumaTotal"
    }
}

}


########################## Procesamiento de archivo #########################
procesar 