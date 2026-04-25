<#
Integrantes: 
            Chavez, Christian                   94529742    
            Masino, Carlos Nicolás              42855529    
            ,Fernando                           11111111    
            ,S                                  11111111            
#>


<#
.SYNOPSIS
Script que identifica archivos duplicados

.DESCRIPTION
Este script identifique los archivos duplicados en un directorio (incluyendo los subdirectorios). Para esto, se considerará que un archivo está duplicado, si su nombre y tamaño son iguales, sin importar su contenido.

.PARAMETER directorio
Directorio a analizar. 


.EXAMPLE
.\ejercicio_3.ps1 -directorio "./test"

.EXAMPLE
.\ejercicio_3.ps1 -directorio "test"


.OUTPUTS
Listado solo con los nombres de los archivos duplicados y en qué path fueron encontrados
#>

########################## Obtencion y control de parametros #########################
param(
    [Parameter(Mandatory=$true)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript({
        if (-not (Test-Path $_ -IsValid)) {
            throw "La ruta ingresada no tiene un formato válido."
        }

        if (-not (Test-Path $_ -PathType Container)) {
            throw "El directorio no existe o no es una carpeta."
        }

        return $true
    })]
    [string]$directorio
)


########################## Funciones #########################
function Procesar {
    param(
        [string]$RutaDirectorio
    )

    try {
        $archivosDuplicados = Get-ChildItem -Path $RutaDirectorio -File -Recurse -ErrorAction Stop |
            Group-Object -Property Name, Length |
            Where-Object { $_.Count -gt 1 }

        if ($archivosDuplicados.Count -eq 0) {
            Write-Host "No se encontraron archivos duplicados."
            return
        }

        foreach ($grupo in $archivosDuplicados) {
            $primerArchivo = $grupo.Group[0]

            Write-Host "archivo: $($primerArchivo.Name)"

            foreach ($archivo in $grupo.Group) {
                Write-Host "directorio: $($archivo.DirectoryName)"
            }

            Write-Host ""
        }
    }
    catch {
        Write-Host "ERROR: Ocurrió un problema al analizar el directorio."
        Write-Host "Detalle: $($_.Exception.Message)"
        exit 1
    }
}


########################## Procesamiento #########################

Procesar -RutaDirectorio $directorio
