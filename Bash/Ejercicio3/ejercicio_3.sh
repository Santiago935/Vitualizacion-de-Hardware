#!/bin/bash

#   Integrantes:                                        #
#                                                       #
#       Chavez, Christian                   94529742    #
#       Masino, Carlos Nicolás              42855529    #
#       ,Fernando                           11111111    #
#       ,S                                  11111111    #
#                                                      


set -Ee #si un comando falla, el script se detiene
set -o pipefail #si falla un pipeline, el script se detiene

######################### Declaracion de variables #########################
# Variables en donde se van a almacenar los parametros de entrada
DIRECTORIO_ENTRADA="";


# Variables para retorno de errores (exit)
PARAMETROS_INVALIDOS=1;
ERROR_DIRECTORIO_ENTRADA=2;


######################### Funciones #########################
MostrarAyuda()
{
    echo
    echo "Nombre script:\"$0\" [-d | --directorio <ruta_a_analizar>]";
    echo "DESCRIPCIÓN: Identifica los archivos duplicados en un directorio (incluyendo los subdirectorios).";
    echo "OPCIONES:";
    echo "  -d, --directorio   Ruta del directorio a analizar.";
    echo "  -h, --help         Muestra este mensaje de ayuda.";     
    echo                    
}


procesar()
{
     #-type f -> busca todos los archivos dentro del directorio (incluyendo subdirectorios)
     #-printf "%f|%s|%h\n" -> le doy formato, por cada archivo nombre|tamaño|directorio
        #%f nombre del archivo
        #%s tamaño
        #%h directorio donde esta
     find "$DIRECTORIO_ENTRADA" -type f -printf "%f|%s|%h\n" | awk -f procesar.awk
}



########################## Obtencion de parametros y controles #########################
opciones=$(getopt -o d:h --l directorio:,help -- "$@" 2> /dev/null);

if [ "$?" != "0" ]
then
    echo "Ingreso una opcion incorrecta";
    exit $PARAMETROS_INVALIDOS;
fi

eval set -- "$opciones";

while true
 do
    case "$1" in
        -d | --directorio)
            DIRECTORIO_ENTRADA="$2";
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
# 1) Verificar que se haya proporcionado un directorio valido
    if [ -z "$DIRECTORIO_ENTRADA" ];
    then
        echo "ERROR: No se ha proporcionado un directorio como parámetro."
        MostrarAyuda
        exit $ERROR_DIRECTORIO_ENTRADA
    fi

    #valido  que exista
    if [ ! -e "$DIRECTORIO_ENTRADA" ]; 
    then
        echo "ERROR: La ruta especificada no existe."
        exit $ERROR_DIRECTORIO_ENTRADA
    fi  
    
    #valido que sea un directorio
    if [ ! -d "$DIRECTORIO_ENTRADA" ]; 
    then
    echo "ERROR: La ruta especificada no es un directorio."
    exit $ERROR_DIRECTORIO_ENTRADA
    fi

    #valido que el directorio tenga permisos de lectura
    if ! [ -r "$DIRECTORIO_ENTRADA" ]; #comando -r valida que el directorio tenga permisos de lectura
    then
        echo "ERROR: No tiene permisos de lectura en el directorio de entrada."
        exit $ERROR_DIRECTORIO_ENTRADA
    fi

########################## Procesamiento de directorio #########################
procesar;

