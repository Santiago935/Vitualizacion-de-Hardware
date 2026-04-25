#!/bin/bash

#   Integrantes:                                        #
#                                                       #
#       Chavez, Christian                   94529742    #
#       Masino, Carlos Nicolás              42855529    #
#       ,Fernando                           11111111    #
#       ,S                                  11111111    #
#                                                      


set -e #si un comando falla, el script se detiene
set -o pipefail #si falla un pipeline, el script se detiene

trap 'echo "Error: ocurrió un problema durante la ejecución del script." ; exit 1' ERR

######################### Declaracion de variables #########################
# Variables en donde se van a almacenar los parametros de entrada
ARCHIVO_ENTRADA="";
DIRECTORIO_SALIDA="";
mostrarPorPantalla=false;
nombre_completo="";
nombre_sin_ext="";
extension="";
nuevo_nombre="";
ruta_salida="";



# Variables para retorno de errores (exit)
PARAMETROS_INVALIDOS=1;
ERROR_ARCHIVO_ENTRADA=2;
ERROR_ARCHIVO_SALIDA=3;


######################### Funciones #########################
MostrarAyuda()
{
    echo
    echo "Nombre script:\"$0\" [-a | --archivo <archivo.txt>] [-s | --salida <ruta_salida>]";
    echo "DESCRIPCIÓN: Este script procesa un archivo TXT y aplica una serie de arreglos automáticos para adecuarlo a las convenciones del idioma español.";
    echo "OPCIONES:";
    echo "  -a, --archivo      Archivo de entrada de texto plano.";
    echo "  -s, --salida       Directorio donde se guardará el archivo corregido. Opcional; si no se informa, se muestra por pantalla.";
    echo "  -h, --help         Muestra este mensaje de ayuda.";     
    echo                    
}


#normalizamos los espacios de la linea usando expresiones regulares
normalizar_espacios()
{
    local linea="$1"

    # Eliminar espacios al inicio
    linea=$(echo "$linea" | sed 's/^[[:space:]]*//')

    # Eliminar espacios al final, para eso uusamos '$' en al expresion regular
    linea=$(echo "$linea" | sed 's/[[:space:]]*$//')

    # Reemplazar multiples espacios por uno solo, con 'g' lo hacemos en toda la linea
    linea=$(echo "$linea" | sed 's/[[:space:]][[:space:]]*/ /g')

    echo "$linea"
}

normalizar_puntuacion()
{
    local linea="$1"

    # 1) Eliminar espacios antes de signos de puntuación
    linea=$(echo "$linea" | sed 's/[[:space:]]\+\([.,;:?!]\)/\1/g')

    # 2) Asegurar un solo espacio después de signos (si hay algo después)
    linea=$(echo "$linea" | sed 's/\([.,;:?!]\)\([^[:space:]]\)/\1 \2/g')

    echo "$linea"
}

normalizar_mayusculas()
{
    local linea="$1"

    # Primera letra luego de comilla doble o simple al inicio
    linea="$(echo "$linea" | sed 's/^\(["'\'']\)\([a-záéíóúñ]\)/\1\U\2/')"

    # Primera letra de la línea en mayúscula
    linea="$(echo "$linea" | sed 's/^\([a-záéíóúñ]\)/\U\1/')"

    # Primera letra después de punto, pregunta o exclamacion
    linea="$(echo "$linea" | sed 's/\([.!?]\) \([a-záéíóúñ]\)/\1 \U\2/g')"

    # Convierte el pronombre "yo" a "Yo" cuando aparece como palabra completa, segun la consigna es opcional
    linea=$(echo "$linea" | sed 's/\<yo\>/Yo/g')

    linea="$(echo "$linea" | sed 's/¿\([a-záéíóúñ]\)/¿\U\1/g')"
    
    linea="$(echo "$linea" | sed 's/¡\([a-záéíóúñ]\)/¡\U\1/g')"

    echo "$linea"
}

normalizar_caracteres()
{
    local linea="$1"

    # Reemplazar puntos suspensivos mal escritos o separados por espacios por "..."
    linea=$(echo "$linea" | sed -E 's/(\.[[:space:]]*){3,}/.../g')

    # Asegurar espacio después de ...
    linea=$(echo "$linea" | sed 's/\.\.\.\([^[:space:]]\)/... \1/g')

    # Unificar comillas dobles
    linea=$(echo "$linea" | sed 's/[“”]/"/g')

    # Unificar comillas simples
    linea=$(echo "$linea" | sed "s/[‘’]/'/g")

    echo "$linea"
}

normalizar_interrogacion_exclamacion()
{
    local linea="$1"

    # Pregunta después de coma
    linea=$(echo "$linea" | sed 's/, \([^¿?]*?\)/, ¿\1/g')

    # Pregunta después de punto
    linea=$(echo "$linea" | sed 's/\. \([^¿?]*?\)/. ¿\1/g')

    # Pregunta después de exclamación
    linea=$(echo "$linea" | sed 's/! \([^¿?]*?\)/! ¿\1/g')

    linea=$(echo "$linea" | sed 's/\.\.\. \([^¿?]*?\)/... ¿\1/g')

    # Pregunta al inicio de línea
    if [[ "$linea" == *"?"* && "$linea" != *"¿"* ]]; then
        linea="¿$linea"
    fi

    # Exclamación después de coma
    linea=$(echo "$linea" | sed 's/, \([^¡!]*!\)/, ¡\1/g')

    # Exclamación después de punto
    linea=$(echo "$linea" | sed 's/\. \([^¡!]*!\)/. ¡\1/g')

    # Exclamación después de pregunta
    linea=$(echo "$linea" | sed 's/? \([^¡!]*!\)/? ¡\1/g')

    # Exclamación al inicio de línea
    if [[ "$linea" == *"!"* && "$linea" != *"¡"* ]]; then
        linea="¡$linea"
    fi

    linea=$(echo "$linea" | sed 's/¡¿/¿/g')

    echo "$linea"
}

normalizar_final_linea()
{
    local linea="$1"

    if [ -n "$linea" ] && [[ ! "$linea" =~ [\.\?\!]$ ]]; then
        linea="${linea}."
    fi

    echo "$linea"
}


normalizar_linea()
{
    local linea="$1"

    # Normalizo comillas antes de aplicar mayúsculas
    linea=$(echo "$linea" | sed 's/[“”]/"/g')
    linea=$(echo "$linea" | sed "s/[‘’]/'/g")

    # Protejo puntos suspensivos para que puntuación no los rompa
    linea=$(echo "$linea" | sed -E 's/(\.[[:space:]]*){3,}/@@@/g')

    linea=$(normalizar_espacios "$linea")
    linea=$(normalizar_puntuacion "$linea")

    # Restauro puntos suspensivos antes de analizar preguntas/exclamaciones
    linea=$(echo "$linea" | sed 's/@@@/.../g')

    linea=$(normalizar_caracteres "$linea")
    linea=$(normalizar_interrogacion_exclamacion "$linea")
    linea=$(normalizar_mayusculas "$linea")
    linea=$(normalizar_final_linea "$linea")

    echo "$linea"
}


normalizar()
{

    #valido si no se muestra por pantalla para vaciar el archivo
      if [ "$mostrarPorPantalla" = false ]; then
        > "$ruta_salida"
        echo "El archivo '$nuevo_nombre' se genero en $DIRECTORIO_SALIDA"
        fi


    while IFS= read -r linea
    do
        linea_corregida=$(normalizar_linea "$linea")

        if [ "$mostrarPorPantalla" = true ]; 
        then
            echo "$linea_corregida"
        else
            echo "$linea_corregida" >> "$ruta_salida"
        fi

    done < "$ARCHIVO_ENTRADA"
}



########################## Obtencion de parametros y controles #########################
opciones=$(getopt -o a:s:h --l archivo:,salida:,help -- "$@" 2> /dev/null);

if [ "$?" != "0" ]
then
    echo "Ingreso una opcion incorrecta";
    exit $PARAMETROS_INVALIDOS;
fi

eval set -- "$opciones";

while true
 do
    case "$1" in
        -a | --archivo)
            ARCHIVO_ENTRADA="$2";
            shift 2;
            ;;
        -s | --salida)
            DIRECTORIO_SALIDA="$2";
            shift 2;
            ;;
        -h | --help)
            MostrarAyuda;
            exit 0;
            ;;
        --)
            shift;
            break;
            ;;
        *)
            echo "Error: Parámetro desconocido '$1'"
            echo "Use -h o --help para ver la ayuda"
            exit 1
            ;;
    esac
done

# control de argumentos sobrantes
if [ $# -gt 0 ]; then
    echo "ERROR: Se ingresaron parámetros no válidos: $*"
    MostrarAyuda
    exit $PARAMETROS_INVALIDOS
fi

#validacion de parametros
# 1) Verificar que se haya proporcionado un archivo valido
if ! [ -n "$ARCHIVO_ENTRADA" ]; # comando '-n' valida que la variable (cadena) no este vacia
then
    echo "ERROR: No se ha proporcionado un archivo como parametro.";
    MostrarAyuda;
    exit $ERROR_ARCHIVO_ENTRADA;
fi

if ! [ -f "$ARCHIVO_ENTRADA" ]; #comando '-f' valida que la variable sea un archivo
then
    echo "El archivo no existe o no es válido.";
    MostrarAyuda;
    exit $ERROR_ARCHIVO_ENTRADA;
fi

if ! [ -s "$ARCHIVO_ENTRADA" ]; #comando '-s' valida que el archivo no este vacio
then
    echo "El archivo esta vacio.";
    MostrarAyuda;
    exit $ERROR_ARCHIVO_ENTRADA;
fi


# 2) Verificar que se haya proporcionado una ruta como salida
if [ -n "$DIRECTORIO_SALIDA" ]; 
then
    if ! [ -d "$DIRECTORIO_SALIDA" ]; 
    then
        echo "ERROR: El directorio de salida no existe o no es válido."
        MostrarAyuda
        exit $ERROR_ARCHIVO_SALIDA
    fi
 
    if ! [ -w "$DIRECTORIO_SALIDA" ]; #comando -w valida que el directorio tenga permisos de escritura
    then
        echo "ERROR: No tiene permisos de escritura en el directorio de salida."
        exit $ERROR_ARCHIVO_SALIDA
    fi

#armo el nombre del archivo final, con 'basename' le saco la ruta del parametro
nombre_completo=$(basename "$ARCHIVO_ENTRADA")

    ##validacion de que el archivo tenga una extension, para evitar errores
    if [[ "$nombre_completo" == *.* ]]; then
        nombre_sin_ext="${nombre_completo%.*}"
        extension="${nombre_completo##*.}"
        nuevo_nombre="${nombre_sin_ext}_corregido.${extension}"
    else
        nuevo_nombre="${nombre_completo}_corregido"
    fi

    ruta_salida="$DIRECTORIO_SALIDA/$nuevo_nombre"

else
    mostrarPorPantalla=true
fi

########################## Procesamiento de archivo #########################
normalizar;