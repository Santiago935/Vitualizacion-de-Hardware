#!/bin/bash

# Agregamos un flag para que si no tiene el flag daemon ejecute nuevamente el script pero en segundo plano.
# Se espera que el flag sea de uso interno y no lo utilice el usuario
if [ "$1" != "--daemon" ]
then
    nohup $(realpath "$0") --daemon "$@" > /dev/null 2>&1 &
    exit 0
fi
shift

######################### Variables #########################
# Variables en donde se van a almacenar los parametros de entrada
directorio="";
palabras="";
log="";
kill=0;

# Variables para retorno de errores (exit)
ERROR_PARAMETROS_INVALIDOS=1;
ERROR_PARAMETRO_DESCONOCIDO=2;
ERROR_PARAMETRO_DIRECTORIO_FALTANTE=3;
ERROR_PARAMETRO_DIRECTORIO_INVALIDO=3;
ERROR_PARAMETRO_LOG_FALTANTE=4;
ERROR_PARAMETRO_LOG_EXISTENTE=5;
ERROR_PARAMETRO_PALABRAS_FALTANTE=6;
ERROR_PARAMETROS_INCOMPATIBLES=7;
ERROR_DEMONIO_EN_EJECUCION=8;
ERROR_ARCHIVO=9;
ERROR_DEMONIO_NO_ENCONTRADO=10;

# Otras variables
NOMBRE_ARCHIVO_LOCKFILE="lockfile";
FORMATO_FECHA_HORA="+%Y-%m-%d-%H:%M:%S";
LOCKFILE="";

########################## Funciones #########################

mostrar_ayuda()
{
    echo
    echo "USO:";
    echo "$0 [-d | --directorio <directorio>] [-p |--palabras <palabras_separadas_por_coma>] [-l | --log <archivo_log>] [-k | --kill]";
    echo
    echo "DESCRIPCIÓN: Este script ejecuta como demonio y detecta cada vez que se realiza una operacion sobre un archivo que contenga alguna de ciertas palabras claves y la registra en un archivo log junto a la fecha, hora y tamaño del archivo. La búsqueda de las palabras se realiza sin tener en cuenta mayúsculas o minúsculas. El script ejecuta sobre un directorio y no pueden ejecutarse al mismo tiempo dos scripts sobre un mismo directorio.";
    echo
    echo "PARAMETROS:";
    echo "  -d, --directorio   Ruta del directorio que contiene los archivos a analizar.";
    echo "  -p, --palabras     Palabras clave separadas por coma. Debe haber al menos una en un archivo del directorio para que se registren sus operaciones.";
    echo "  -l, --log          Ruta del archivo log donde se guardan las operaciones realizadas sobre los archivos."
    echo "  -k, --kill         Indica que debe finalizar la ejecucion del demonio asociado al directorio indicado."
    echo "  -h, --help         Muestra este mensaje de ayuda.";
    echo                    
}

archivo_tiene_palabras_clave() {
    local archivo=$1;
    local palabras_clave_csv=$2;

    local IFS=',';

    # Guardamos cada palabra clave en un array
    read -ra palabras_clave <<< "$palabras_clave_csv";
    
    # Validamos si el contenido del archivo contiene alguna palabra clave
    for palabra_clave in "${palabras_clave[@]}"
    do
        # Devuelve 0 si encontró al menos una palabra clave
        if grep -qi "$palabra_clave" "$archivo"
        then
            return 0;
        fi
    done

    # Devuelve 1 si no se encontró ninguna palabra clave
    return 1;
}

function manejador_fin() {
    # Eliminamos el lockfile siempre que finalice la ejecucion
    rm -f "$LOCKFILE";
}

main() {
    LOCKFILE="$directorio/$NOMBRE_ARCHIVO_LOCKFILE";

    if [ ! -f "$LOCKFILE" ] && [ $kill -eq 1 ]
    then
        echo "ERROR: no hay ningún demonio ejecutando en el directorio indicado";
        exit $ERROR_DEMONIO_NO_ENCONTRADO;
    fi

    # Creamos archivo lockfile para que otros demonios puedan detectar si ya hay un demonio corriendo en el directorio asignado
    # Antes verificamos si ya hay un demonio ejecutando en el directorio y si lo hay, evitamos una nueva ejecucion
    if [ -f "$LOCKFILE" ]
    then
        pid_lockfile=$(cat "$LOCKFILE")
        # Verificamos si existe un proceso con el PID almacenado en el lockfile
        if kill -0 "$pid_lockfile" 2>/dev/null
        then
            if [[ $kill -eq 1 ]]
            then
                kill -- -$(ps -o pgid= "$pid_lockfile" | tr -d ' ')
                exit 0;
            else
                echo "ERROR: el directorio está bloqueado por otra instancia del script.";
                exit $ERROR_DEMONIO_EN_EJECUCION;
            fi
        else
            # El lockfile no está en uso y lo eliminamos
            rm -f "$LOCKFILE"
        fi       
    fi

    if ! touch "$LOCKFILE" 2>/dev/null || [ -d "$log" ]
    then
        echo "ERROR: no se pudo crear el archivo de bloqueo de directorio.";
        exit $ERROR_ARCHIVO;
    fi

    # Manejamos la finalización del proceso para eliminar el lockfile
    trap manejador_fin EXIT;

    # Escribimos el PID en el lockfile
    echo $$ > "$LOCKFILE";

    # Creamos el archivo log
    if ! touch "$log" 2>/dev/null || [ -d "$log" ]
    then
        echo "ERROR: no se pudo crear el archivo del log.";
        exit $ERROR_ARCHIVO;
    fi

    # Guardamos en un array asociativo todos los archivos que contengan al menos una palabra clave.
    # De esta forma podemos saber si un archivo que no fue modificado y que ya tenia al menos una palabra clave sigue cumpliendo la condición,
    # sin necesidad de volver a leer el archivo.
    declare -A archivos_logueados;

    for archivo in "$directorio"/*
    do
        # Verificamos si es un archivo por si el directorio está vacío
        if [ -f "$archivo" ] && [[ "$ruta_archivo" != "$LOCKFILE" ]] && [[ "$ruta_archivo" != "$log" ]] && archivo_tiene_palabras_clave "$archivo" "$palabras"
        then
            archivos_logueados["$archivo"]=1;
        fi
    done

    inotifywait -m -e access,close_write,create,delete --format '%e %w %f' "$directorio" | while read -r evento ruta nombre_archivo
    do
        local ruta_archivo="$ruta$nombre_archivo";
        local tam_archivo=$(stat -c %s "$ruta_archivo");

        if [[ "$ruta_archivo" == "$LOCKFILE" ]] || [[ "$ruta_archivo" == "$log" ]]
        then
            continue;
        fi

        if [[ ${archivos_logueados["$ruta_archivo"]} -eq 1 ]] # Si el archivo está en el array de archivos que hay que registrar en log
        then
            case "$evento" in
                *"CLOSE_WRITE"*)
                    echo "$(date $FORMATO_FECHA_HORA): Se escribio el archivo \"$nombre_archivo\" ($tam_archivo bytes)." >> "$log"

                    # Si el archivo fue modificado y ya no contiene más las palabras clave lo quitamos del array
                    if ! archivo_tiene_palabras_clave "$ruta_archivo" "$palabras"
                    then
                        archivos_logueados["$ruta_archivo"]=0
                        echo "$(date $FORMATO_FECHA_HORA): Se deja de loguear el archivo \"$nombre_archivo\" ($tam_archivo bytes)." >> "$log"
                    fi
                    ;;
                *"DELETE"*)
                    echo "$(date $FORMATO_FECHA_HORA): Se elimino el archivo \"$nombre_archivo\" ($tam_archivo bytes)." >> "$log"
                    # Quitamos del array el archivo eliminado
                    archivos_logueados["$ruta_archivo"]=0
                    ;;
                *"ACCESS"*)
                    echo "$(date $FORMATO_FECHA_HORA): Se leyo el archivo \"$nombre_archivo\" ($tam_archivo bytes)." >> "$log"
                    ;;
            esac
        elif [[ $evento == *"CLOSE_WRITE"* ]] && archivo_tiene_palabras_clave "$ruta_archivo" "$palabras" # Si el archivo no estaba en el array y fue modificado revisamos si ahora sí contiene alguna palabra clave
        then
            # Lo agregamos al array y dejamos registro en el log
            archivos_logueados["$ruta_archivo"]=1
            echo "$(date $FORMATO_FECHA_HORA): Se empieza a loguear el archivo \"$nombre_archivo\" ($tam_archivo bytes)" >> "$log"
        fi
    done
}

########################## Parámetros #########################

options=$(getopt -o d:p:l:kh --l directorio:,palabras:,log:,kill,help -- "$@" 2> /dev/null)
if [ "$?" != "0" ]
then
    echo 'Opciones incorrectas';
    exit $ERROR_PARAMETROS_INVALIDOS;
fi

eval set -- "$options";
while true
do
    case "$1" in
        -d | --directorio)
            directorio="$2";
            shift 2;
            ;;
        -l | --log)
            log="$2";
            shift 2;
            ;;
        -p | --palabras)
            palabras="$2";
            shift 2;
            ;;
        -k | --kill)
            kill=1;
            shift 1;
            ;;
        -h | --help)
            mostrar_ayuda;
            exit 0;
            ;;
        --)
            shift
            break
            ;;
        *) # default: 
            echo "Error: Parámetro desconocido '$1'";
            echo "Use -h o --help para ver la ayuda.";
            exit $ERROR_PARAMETRO_DESCONOCIDO;
            ;;
    esac
done

# Validamos que se haya especificado el directorio
if [ -z $directorio ]
then
    echo "ERROR: se debe especificar el directorio";
    mostrar_ayuda;
    exit $ERROR_PARAMETRO_DIRECTORIO_FALTANTE;
fi

# Validamos que el directorio sea correcto
if [ ! -d $directorio ]
then
    echo "ERROR: el directorio especificado es invalido";
    mostrar_ayuda;
    exit $ERROR_PARAMETRO_DIRECTORIO_INVALIDO;
fi

if [ $kill -eq 1 ] # Validamos que no se haya pasado el parametro kill junto a otros parametros incompatibles
then
    if [ -n "$log" ]
    then
        echo "ERROR: no puede ingresar el parametro -l/--log y -k/--kill al mismo tiempo.";
        mostrar_ayuda;
        exit $ERROR_PARAMETROS_INCOMPATIBLES;
    fi

    if [ -n "$palabras" ]
    then
        echo "ERROR: no puede ingresar el parametro -p/--palabras y -k/--kill al mismo tiempo.";
        mostrar_ayuda;
        exit $ERROR_PARAMETROS_INCOMPATIBLES;
    fi
else # Si no se pasa el parametro kill verificamos que se pasen todos los parámetros necesarios para crear el demonio y que sean válidos
    if [ -z "$log" ]
    then
        echo "ERROR: falta el parametro -l/--log.";
        exit $ERROR_PARAMETRO_LOG_FALTANTE;
    fi
    if [ -f $log ]
    then
        echo "ERROR: el archivo log ya existe.";
        mostrar_ayuda;
        exit $ERROR_PARAMETRO_LOG_EXISTENTE;
    fi

    if [ -z "$palabras" ]
    then
        echo "ERROR: falta el parametro -p/--palabras";
        mostrar_ayuda;
        exit $ERROR_PARAMETRO_PALABRAS_FALTANTE;
    fi
fi

########################## Ejecución #########################

main