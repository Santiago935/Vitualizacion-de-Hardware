
<#
Integrantes: 
            Chavez, Christian                   94529742    
            Masino, Carlos Nicolás              42855529    
            ,Fernando                           11111111    
            Manghi Scheck, Santiago             95054445    
#>

<#


.SYNOPSIS
Script que registra operaciones sobre archivos de un directorio en un log.

.DESCRIPTION
Este script se ejecuta como demonio y tiene la funcionalidad de registrar en un archivo de log las operaciones realizadas sobre el directorio indicado.
Solo se registran las operaciones de aquellos archivos que contengan al menos una de las palabras clave indicadas.
No puede ejecutarse más de una vez de forma simultánea sobre un mismo directorio.

.PARAMETER directorio
Directorio de los archivos a analizar.

.PARAMETER log
Ruta del archivo donde se guardan los registros del log.

.PARAMETER palabras
Cadena de texto con las palabras clave separadas por coma.

.PARAMETER kill
Flag para inidicar que debe finalizar el demonio ejecutando en el directorio indicado.


.EXAMPLE
.\ejercicio4.ps1 --directorio "./directorio" --log ."/log.txt" --palabras password,account,unlam

.EXAMPLE
.\ejercicio4.ps1 --directorio "./directorio" --kill

.OUTPUTS
Archivo de log con las operaciones realizadas sobre los archivos monitoreados.
#>

[CmdletBinding()]
param(
    [Parameter(Mandatory = $True)]
    [ValidateNotNullOrEmpty()]
    [ValidateScript(
        {
            Test-Path $_ -PathType Container
        },
        ErrorMessage = "El directorio a monitorear no existe"   
    )]
    [string]$directorio,

    [Parameter(Mandatory = $True, ParameterSetName = "Iniciar")]
    [ValidateNotNullOrEmpty()]
    [ValidateScript(
        {
            $ruta_archivo = $ExecutionContext.SessionState.Path.GetUnresolvedProviderPathFromPSPath($_)
            $directorio_log = Split-Path $ruta_archivo -Parent

            if (-not (Test-Path -Path $directorio_log -PathType Container)) {
                throw "El directorio del archivo log no existe."
            }

            if (Test-Path $ruta_archivo) {
                throw "Ya existe un elemento en la ruta del archivo log especificada."
            }

            return $True
        }
    )]
    [string]$log,

    [Parameter(Mandatory = $True, ParameterSetName = "Iniciar")]
    [ValidateNotNullOrEmpty()]
    [string[]]$palabras,

    [Parameter(Mandatory = $True, ParameterSetName = "Finalizar")]
    [switch]$kill,

    [Parameter(Mandatory = $False, DontShow = $true)]
    [switch]$daemon
)

######################### Variables #########################

# Variables para retorno de errores (exit)
$ERROR_DEMONIO_EN_EJECUCION = 1
$ERROR_ARCHIVO = 2
$ERROR_DEMONIO_NO_ENCONTRADO = 3

# Otras variables
$NOMBRE_ARCHIVO_LOCKFILE = "lockfile"
$FORMATO_FECHA_HORA = "dd/MM/yyyy HH:mm:ss"
$LOCKFILE = Join-Path $directorio $NOMBRE_ARCHIVO_LOCKFILE

# PARAMS para ejecutar como demonio
$PARAMS = $PSBoundParameters.GetEnumerator() | ForEach-Object {
    if ($_.Value -is [switch]) {
        "-$($_.Key)"
    }
    elseif ($_.Value -is [string[]]) {
        "-$($_.Key) $($_.Value -join ',')"
    }
    else {
        "-$($_.Key) `"$($_.Value)`""
    }
}
$PARAMS = ($PARAMS -join " ") + " -daemon"

########################## Funciones #########################

function Nuevo-Archivo {
    param (
        [string]$Nombre_Archivo,
        [string]$Mensaje_Error
    )
    
    try {
        New-Item -Path $Nombre_Archivo -ItemType File -ErrorAction Stop | Out-Null
    }
    catch {
        if (-not $Mensaje_Error) {
            $Mensaje_Error = "ERROR: no se pudo crear el archivo ""$Nombre_Archivo."""
        }

        Write-Error $Mensaje_Error
        return $false
    }

    return $true
}

function Crear-Watcher() {
    $watcher = New-Object System.IO.FileSystemWatcher
    $watcher.Path = Resolve-Path $directorio
    $watcher.IncludeSubdirectories = $false
    $watcher.EnableRaisingEvents = $true

    return $watcher
}

function Main {
    if (-not (Test-Path $LOCKFILE -PathType Leaf) -and $kill) {
        Write-Error "ERROR: no hay ningún demonio ejecutando en el directorio indicado";
        exit $ERROR_DEMONIO_NO_ENCONTRADO
    }

    # Creamos archivo lockfile para que otros demonios puedan detectar si ya hay un demonio corriendo en el directorio asignado
    # Antes verificamos si ya hay un demonio ejecutando en el directorio y si lo hay, evitamos una nueva ejecucion
    if (Test-Path $LOCKFILE -PathType Leaf) {
        $pid_lockfile = Get-Content $Lockfile

        # Verificamos si existe un proceso con el PID almacenado en el lockfile
        if (Get-Process -Id $pid_lockfile -ErrorAction SilentlyContinue) {
            # Como existe el proceso, si se pasó el flag kill lo finalizamos. Caso contrario no se puede continuar.
            if ($kill) {
                Stop-Process -Id $pid_lockfile -Force
                Remove-Item $LOCKFILE -Force -ErrorAction SilentlyContinue
                exit 0
            }
            else {
                Write-Error "ERROR: el directorio está bloqueado por otra instancia del script."
                exit $ERROR_DEMONIO_EN_EJECUCION
            }
        }
        else {
            # El lockfile no está en uso y lo eliminamos
            Remove-Item $LOCKFILE -ErrorAction SilentlyContinue
        }
    }

    # Iniciamos como demonio
    if (-not $daemon) {
        Start-Process -FilePath pwsh -ArgumentList "-File `"$PSCommandPath`" $params" -WindowStyle Hidden
        exit 0
    }

    # Creamos archivo lockfile
    if (-not (Nuevo-Archivo $LOCKFILE)) {
        exit $ERROR_ARCHIVO
    }
    try {
        # Escribimos el PID en el lockfile
        $PID | Out-File -FilePath $LOCKFILE

        if (-not (Nuevo-Archivo $log)) {
            exit $ERROR_ARCHIVO
        }
        
        # Guardamos en un array asociativo todos los archivos que contengan al menos una palabra clave.
        # De esta forma podemos saber si un archivo que no fue modificado y que ya tenia al menos una palabra clave sigue cumpliendo la condición,
        # sin necesidad de volver a leer el archivo.
        $archivos_registrados = @{}
        
        Get-ChildItem -Path $directorio -File | ForEach-Object {
            $archivo = $_
            $ruta_archivo = $archivo.FullName
            if ($(Resolve-Path $ruta_archivo).Path -eq $(Resolve-Path $LOCKFILE).Path -or
                $(Resolve-Path $ruta_archivo).Path -eq $(Resolve-Path $log).Path) {
                return;
            }

            $contenido = Get-Content $ruta_archivo -Raw
            $contiene_palabra = $palabras -split "," | Where-Object { $contenido -match $_ }
            if ($contiene_palabra) {
                $tam_archivo = $archivo.Length
                
                $archivos_registrados[$ruta_archivo] = $tam_archivo
                "$(Get-Date -Format $FORMATO_FECHA_HORA): Se empieza a loguear el archivo ""$ruta_archivo"" ($tam_archivo bytes)." | Out-File -FilePath $log -Append
            }
        }
        
        $watcher = Crear-Watcher

        $messageData = @{
            archivos_registrados = $archivos_registrados
            palabras             = $palabras
            log                  = $log
            FORMATO_FECHA_HORA   = $FORMATO_FECHA_HORA
            LOCKFILE             = $LOCKFILE
        }

        Register-ObjectEvent -InputObject $watcher -EventName "Changed" -MessageData $messageData -Action {
            $ruta_archivo = $Event.SourceEventArgs.FullPath

            if ($(Resolve-Path $ruta_archivo).Path -eq $(Resolve-Path $EVENT.MessageData.LOCKFILE).Path -or
                $(Resolve-Path $ruta_archivo).Path -eq $(Resolve-Path $EVENT.MessageData.log).Path) {
                return;
            }
            
            $tam_archivo = (Get-Item $ruta_archivo).Length
            $esta_en_array = $Event.MessageData.archivos_registrados.ContainsKey($ruta_archivo)

            $contenido = Get-Content $ruta_archivo -Raw
            $contiene_palabra = $Event.MessageData.palabras -split "," | Where-Object { $contenido -match $_ }

            # Si el archivo está en el array entonces se registra en el log que fue modificado
            if ($esta_en_array) {
                "$(Get-Date -Format $Event.MessageData.FORMATO_FECHA_HORA): Se escribió el archivo ""$ruta_archivo"" ($tam_archivo bytes)." | Out-File -FilePath $Event.MessageData.log -Append
                
                # Si no contiene palabras clave es porque en el cambio se eliminaron y ya no tiene que registrarse más en el log
                if (-not $contiene_palabra) {
                    $Event.MessageData.archivos_registrados.Remove($ruta_archivo)
                    "$(Get-Date -Format $Event.MessageData.FORMATO_FECHA_HORA): Se deja de registrar el archivo ""$ruta_archivo"" ($tam_archivo bytes)." | Out-File -FilePath $Event.MessageData.log -Append
                }
            }
            else {
                # Como no está en el array, si contiene palabras clave es porque se agregaron en la modificación y ahora hay que registrar en el log
                if ($contiene_palabra) {
                    "$(Get-Date -Format $Event.MessageData.FORMATO_FECHA_HORA): Se empieza a registrar el archivo ""$ruta_archivo"" ($tam_archivo bytes)." | Out-File -FilePath $Event.MessageData.log -Append
                    $Event.MessageData.archivos_registrados[$ruta_archivo] = $tam_archivo
                }
            }
        }

        Register-ObjectEvent -InputObject $watcher -EventName "Deleted" -MessageData $messageData -Action {
            $ruta_archivo = $Event.SourceEventArgs.FullPath

            if (-not $Event.MessageData.archivos_registrados.ContainsKey($ruta_archivo)) {
                return
            }

            $tam_archivo = $Event.MessageData.archivos_registrados[$ruta_archivo]
            $Event.MessageData.archivos_registrados.Remove($ruta_archivo)
            "$(Get-Date -Format $script:FORMATO_FECHA_HORA): Se eliminó el archivo ""$ruta_archivo"" ($tam_archivo bytes)." | Out-File -FilePath $Event.MessageData.log -Append
            "$(Get-Date -Format $Event.MessageData.FORMATO_FECHA_HORA): Se deja de registrar el archivo ""$ruta_archivo"" ($tam_archivo bytes)." | Out-File -FilePath $Event.MessageData.log -Append
        }

        Wait-Event
    }
    finally {
        if (Test-Path $LOCKFILE -PathType Leaf) {
            Remove-Item $LOCKFILE -ErrorAction SilentlyContinue
        }
    }
}

########################## Ejecución #########################

Main