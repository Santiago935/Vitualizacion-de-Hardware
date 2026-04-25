<#
Integrantes: 
            Chavez, Christian                   94529742    
            Masino, Carlos Nicolás              42855529    
            ,Fernando                           11111111    
            ,S                                  11111111            
#>


<#
.SYNOPSIS
Script que normaliza un archivo de texto

.DESCRIPTION
Este script procesa un archivo de texto y realiza una serie de arreglos automáticos para adecuarlo a las convenciones del idioma español.
Realiza estas correciones: 
• Puntuacion.
• Uso de mayúsculas.
• Signos de interrogación y exclamación.
• Espaciado y formato.
• Normalización de caracteres.

.PARAMETER archivo
Archivo de texto a procesar. 

.PARAMETER salida
Opcional, directorio donde se va a generar el archivo corregido, si no se indica nada se muestra por pantalla. 


.EXAMPLE
.\ejercicio_2.ps1 -archivo "lotes/prueba1.txt"

.EXAMPLE
.\ejercicio_2.ps1 -archivo "prueba1.txt"

.EXAMPLE
.\ejercicio_2.ps1 -archivo "lotes/prueba1.txt" -salida "./salida"


.OUTPUTS
Si se indico ruta de salida se muestra mensaje indicando que se genero correctamente el archivo, sino, se muestra el resultado por pantalla
#>


########################## Obtencion y control de parametros #########################
param(
    [Parameter(Mandatory=$true)][ValidateNotNullOrEmpty()]
    [ValidateScript({
        if (-not (Test-Path $_ -PathType Leaf)) {
            throw "El archivo indicado no existe o no es un archivo válido."
        }
        if ((Get-Item $_).Length -eq 0) {
            throw "El archivo indicado está vacío."
        }
        return $true
    })]
    [string]$archivo,

    [Parameter(Mandatory=$false)][ValidateNotNullOrEmpty()]
    [ValidateScript({
        if (-not (Test-Path $_ -PathType Container)) {
            throw "El directorio de salida indicado no existe."
        }
        return $true
    })]
    [string]$salida
)

######################### Funciones #########################
function Normalizar-Espacios {
    param(
        [string]$linea
    )

    # Eliminar espacios al inicio y al final
    $linea = $linea.Trim()

    # Reemplazar múltiples espacios por uno solo
    $linea = $linea -replace '\s+', ' '

    return $linea
}

function Normalizar-Puntuacion {
    param(
        [string]$linea
    )

    # 1) Eliminar espacios antes de signos
    $linea = $linea -replace '\s+([.,;:?!])', '$1'

    # 2) Asegurar un espacio después de signos
    $linea = $linea -replace '([.,;:?!])([^\s])', '$1 $2'

    return $linea
}

function Normalizar-Mayusculas {
    param(
        [string]$linea
    )

    # 1) Primera letra de la línea
    if ($linea.Length -gt 0) {
        $linea = $linea.Substring(0,1).ToUpper() + $linea.Substring(1)
    }

    # Primera letra después de comilla simple o doble al inicio de la línea
    $linea = [regex]::Replace($linea, '^(["''])([a-záéíóúñ])', {
    param($m)
    $m.Groups[1].Value + $m.Groups[2].Value.ToUpper()
    })

    # 2) Después de punto, ?, !
    $linea = [regex]::Replace($linea, '([.!?]\s+)([a-záéíóúñ])', {
        param($m)
        $m.Groups[1].Value + $m.Groups[2].Value.ToUpper()
    })

    # 3) Después de ¿ o ¡
    $linea = [regex]::Replace($linea, '([¿¡])([a-záéíóúñ])', {
        param($m)
        $m.Groups[1].Value + $m.Groups[2].Value.ToUpper()
    })

    # 4) "yo" como palabra completa
    $linea = $linea -replace '\byo\b', 'Yo'

    return $linea
}

function Normalizar-Caracteres {
    param(
        [string]$linea
    )

    # Reemplazar puntos suspensivos mal escritos por "..."
    $linea = $linea -replace '(\.\s*){3,}', '...'

    # Asegurar espacio después de "..."
    $linea = $linea -replace '\.\.\.([^\s])', '... $1'

    # Unificar comillas dobles
    $linea = $linea -replace '[“”]', '"'

    # Unificar comillas simples
    $linea = $linea -replace '[‘’]', "'"

    return $linea
}

function Normalizar-InterrogacionExclamacion {
    param(
        [string]$linea
    )

    # Agregar signo de apertura de pregunta cuando la pregunta aparece después de un punto.
    $linea = [regex]::Replace($linea, '(\.\s+)([^¿?]*\?)', {
        param($m)
        $m.Groups[1].Value + '¿' + $m.Groups[2].Value
    })

    # Agregar signo de apertura de pregunta cuando la pregunta aparece después de una coma.
    $linea = [regex]::Replace($linea, '(,\s+)([^¿?]*\?)', {
        param($m)
        $m.Groups[1].Value + '¿' + $m.Groups[2].Value
    })

    # Agregar signo de apertura de pregunta cuando la pregunta aparece después de puntos suspensivos.
    $linea = [regex]::Replace($linea, '(\.\.\.\s+)([^¿?]*\?)', {
        param($m)
        $m.Groups[1].Value + '¿' + $m.Groups[2].Value
    })

    # Si la línea contiene una pregunta y todavía no tiene signo de apertura, se agrega al inicio.
    if ($linea -match '\?' -and $linea -notmatch '¿') {
        $linea = "¿$linea"
    }

    # Agregar signo de apertura de exclamación cuando la exclamación aparece después de un punto.
    $linea = [regex]::Replace($linea, '(\.\s+)([^¡!]*!)', {
        param($m)
        $m.Groups[1].Value + '¡' + $m.Groups[2].Value
    })

    # Agregar signo de apertura de exclamación cuando la exclamación aparece después de una coma.
    $linea = [regex]::Replace($linea, '(,\s+)([^¡!]*!)', {
        param($m)
        $m.Groups[1].Value + '¡' + $m.Groups[2].Value
    })

    # Agregar signo de apertura de exclamación cuando la exclamación aparece después de una pregunta.
    $linea = [regex]::Replace($linea, '(\?\s+)([^¡!]*!)', {
        param($m)
        $m.Groups[1].Value + '¡' + $m.Groups[2].Value
    })

    # Si la línea contiene una exclamación y todavía no tiene signo de apertura, se agrega al inicio.
    if ($linea -match '!' -and $linea -notmatch '¡') {
        $linea = "¡$linea"
    }

    # Evitar combinaciones incorrectas como "¡¿".
    $linea = $linea -replace '¡¿', '¿'

    return $linea
}

function Normalizar-FinalLinea {
    param(
        [string]$linea
    )

    if ($linea -and $linea -notmatch '[\.\?\!]$') {
        $linea = "$linea."
    }

    return $linea
}


function Normalizar-Linea {
    param( [string]$linea )

    $linea = Normalizar-Espacios $linea
    $linea = Normalizar-Puntuacion $linea
    $linea = Normalizar-Caracteres $linea
    $linea = Normalizar-InterrogacionExclamacion $linea
    $linea = Normalizar-Mayusculas $linea
    $linea = Normalizar-FinalLinea $linea

    return $linea
}

function Normalizar {
    $lineasCorregidas = @() #generamos un vector vacio para ir guardando las lineas corregidas

    Get-Content -Path $archivo | ForEach-Object {
        $lineaCorregida = Normalizar-Linea $_
        $lineasCorregidas += $lineaCorregida
    }

    if ($salida) {
        $nombreCompleto = Split-Path $archivo -Leaf #devuelve el nombre del archivo sin la ruta
        $nombreSinExt = [System.IO.Path]::GetFileNameWithoutExtension($nombreCompleto)
        $extension = [System.IO.Path]::GetExtension($nombreCompleto)

        $nuevoNombre = "$nombreSinExt`_corregido$extension"
        $rutaSalida = Join-Path $salida $nuevoNombre

        $lineasCorregidas | Set-Content -Path $rutaSalida #escribe el contenido del vector lienascorregidas al archivo salida

        Write-Host "El archivo '$nuevoNombre' se generó en '$salida'."
    }
    else {
        $lineasCorregidas
    }
}

########################## Procesamiento de archivo #########################
normalizar 