#!/bin/bash

#########################################################
#               Virtualizacion de Hardware              #
#                                                       #
#   APL1 - Ejercicio 1                                  #
#   Nombre del script: Ejercicio1.sh                    #
#                                                       #
#   Integrantes:                                        #
#                                                       #
#       Ocampo, Nicole Fabiana              44451238    #
#       Sandoval Vasquez, Juan Leandro      41548235    #
#       Vivas, Pablo Ezequiel               38703964    #
#       Villegas, Lucas Ezequiel            37792844    #
#       Tigani, Martin Sebastian            32788835    #
#                                                       #
#   Instancia de entrega: Reentrega                     #
#                                                       #
#########################################################

# ================================= Variables =================================

# Variables en donde se van a almacenar los parametros de entrada
declare directorioEntrada="";
declare rutaArchivoSalida="";
declare mostrarPorPantalla=false;

# Vector asociativo en donde se van a guardar las notas finales
declare -A vectorNotas;

# Variable en formato JSON para guardar en el archivo de salida o mostrarlo por pantalla
declare jsonData=$(jq -n '{ "notas": [] }');

# Variables para retorno de errores (exit)
declare ERROR_PARAMETROS_INVALIDOS=1;
declare ERROR_ARGUMENTO_DESCONOCIDO=2;
declare ERROR_DIRECTORIO=3;
declare ERROR_ARCHIVO_SALIDA_Y_PANTALLA=4;
declare ERROR_DIRECTORIO_SIN_ARCHIVOS=5;
declare ERROR_EXTENSION=6;
declare ERROR_RUTA_INVALIDA=7;

# ================================= Funciones =================================

function ayuda() {
    echo "USO: $0 [-d|--directorio <directorio_entrada_archivos_csv>] [-s|--salida <ruta_archivo_json_salida>] [-p|--pantalla]";
    echo "DESCRIPCIÓN: Este script procesa archivos CSV de notas de finales y genera un archivo JSON con el resumen de las notas de los alumnos.";
    echo "OPCIONES:";
    echo "  -d, --directorio   Ruta del directorio que contiene los archivos CSV a procesar.";
    echo "  -s, --salida       Ruta del archivo JSON de salida.";
    echo "  -p, --pantalla     Muestra la salida por pantalla, no genera el archivo JSON.";
    echo "  -h, --help         Muestra este mensaje de ayuda.";
    echo "ACLARACIONES: Para este ejercicio se utiliza el comando jq, por lo tanto, es necesaria su instalacion (sudo apt install jq)";
}

# calcularNotaFinal: Por cada registro, se acumulan las notas en una variable para luego 
# dividirla por la cantidad de ejercicios. notasAlumno tendra todo el registro del 
# alumno (una linea del archivo a procesar). Saco el promedio y trunco la nota en caso de 
# que quede en decimales

function calcularNotaFinal() {
    local notasAlumno=("$@");
    local sumaNotas=0;
    for (( i = 1; i < ${#notasAlumno[@]}; i++ )); do
        local valorNota=$(determinarValorNota "${notasAlumno[i]}");
        sumaNotas=$(LC_NUMERIC=C awk "BEGIN {print ${sumaNotas} + $valorNota}");
    done
    awk "BEGIN {printf \"%.0f\", ($sumaNotas / $cantidadDeEjercicios) * 10}";
}

# determinarValorNota: Devuelve el valor numerico por cada resolucion de ejercicio.

function determinarValorNota() {
    case "$1" in
        "B" | "b")
            echo 1 ;;
        "R" | "r")
            echo 0.5 ;;
        "M" | "m")
            echo 0 ;;
        *)
            echo -1 ;;
    esac
}

# eliminarExtensionArchivo: Los utilizo para los archivos a procesar ya que sus nombre 
# tienen el codigo de materia.

function eliminarExtensionArchivo() {
    echo "$(basename "${1%.*}")";
}

# mostrarOGuardarArchivoJson: Determina segun los parametros de entrada, si se muestra
# por pantalla o si se almacena en un archivo JSON

function mostrarOGuardarArchivoJson() {
    if [ "$mostrarPorPantalla" = true ]; then
        echo "$jsonData";
    else
        echo "$jsonData" > "$rutaArchivoSalida";
        echo "El archivo JSON fue generado exitosamente en la ruta indicada $rutaArchivoSalida";
    fi
}

# obtenerCantidadDeEjercicios: La cantidad de ejercicios sera igual a todos los elementos que haya 
# en el registro menos el primer campo, que es el DNI del alumno.

function obtenerCantidadDeEjercicios() {
    local registro=($(head -n 1 "$1" | tr ',' '\n'));
    local cantidadDeEjercicios=$(( ${#registro[@]} - 1 ));
    echo "$cantidadDeEjercicios";
}

# validarArchivoCSV: valida que tanto el nombre del archivo como el encabezado tengan los formatos correctos.

function validarArchivoCSV() {
    local encabezado=$(head -n 1 "$1");
    if ! validarEncabezado "$encabezado"; then 

        return 1; 
    fi
    return 0
}

# validarEncabezado: Valida que el encabezado del archivo CSV sea de la forma DNI-alumno,nota-ej-0,...,nota-ej-N

function validarEncabezado() {
    local encabezado="$1";
    local formatoDniAlumno="DNI-alumno";
    local formatoEjercicio="nota-ej-";
    IFS=',' read -r -a campos <<< "$encabezado";
    if [ "${campos[0]}" != "$formatoDniAlumno" ]; then
        return 1;
    fi
    for ((i = 1; i < ${#campos[@]}; i++)); do
        local formatoCampo=$(expr match "${campos[$i]}" '\([a-zA-Z-]*\)');
        local campoNumero=$(echo "${campos[$i]}" | sed 's/[^0-9]*//g');
        if [ "$formatoCampo" != "$formatoEjercicio" ] || ! [[ "$campoNumero" =~ ^[0-9]+$ ]]; then
            return 1;
        fi
    done
    return 0;
}

# armarArchivoJson: Construye la salida en base al vector asociacito declarado (ver main).
# Busco el dni del alumno si se encuentra en el JSON
#   Si no se encuentra, armo la estructura para un alumno nuevo
# Caso contrario
#   Busco la ubicacion del DNI del alumno y agrego la materia nueva

function armarArchivoJson() {
    for nota in "${!vectorNotas[@]}"; do    
        dni=$(echo "$nota" | cut -d '-' -f1);
        materia=$(echo "$nota" | cut -d '-' -f2);
        notaFinal=${vectorNotas["$nota"]};
        dniEncontrado=$(echo "$jsonData" | jq -r --arg dni "$dni" '.notas[] | select(.dni == $dni)');
        if [ -z "$dniEncontrado" ]; then
            nuevoAlumno=$(jq -n --arg dni "$dni" --arg materia "$materia" --arg nota "$notaFinal" '{ dni: $dni, notas: [{ materia: $materia, nota: $nota }] }');
            jsonData=$(echo "$jsonData" | jq --argjson nuevoAlumno "$nuevoAlumno" '.notas += [$nuevoAlumno]');
        else
            jsonData=$(echo "$jsonData" | jq --arg dni "$dni" --arg materia "$materia" --arg nota "$notaFinal" '.notas |= map(if .dni == $dni then .notas += [{ materia: $materia, nota: $nota }] else . end)');
        fi
    done
}

function main() {

    if ! ls "$directorioEntrada"/*.csv &>/dev/null; then
        echo "ERROR: No se encontraron archivos CSV en el directorio especificado.";
        exit $ERROR_DIRECTORIO_SIN_ARCHIVOS;
    fi
    
    for archivoCSV in "$directorioEntrada"/*.csv; do

        if ! validarArchivoCSV "$archivoCSV"; then
            echo "ERROR: El archivo $archivoCSV no es válido o no se puede procesar.";
            continue;
        fi
        
        cantidadDeEjercicios=$(obtenerCantidadDeEjercicios "$archivoCSV");

        lineaEncabezado=true;

        materia=$(eliminarExtensionArchivo "$archivoCSV")

        while IFS=',' read -a registro; do
            # Omito el encabezado
            if $lineaEncabezado; then
                lineaEncabezado=false;
                continue;
            fi

            # Armo las claves del vector asociativo, es una clave compuesta por DNI-Materia
            # la cual almaceno la nota final que tiene

            dniAlumno="${registro[0]}";

            notaFinal=$(calcularNotaFinal "${registro[@]}");

            vectorNotas["$dniAlumno-$materia"]=$notaFinal;
        
        done < "$archivoCSV"
    done

    armarArchivoJson;

    mostrarOGuardarArchivoJson;
}

# ================================= Controles =================================

opciones=$(getopt -o d:s:ph --l directorio:,salida:,pantalla,help -- "$@" 2> /dev/null);

if [ "$?" != "0" ]; then
    echo "Opcion/es incorrectas";
    exit $ERROR_PARAMETROS_INVALIDOS;
fi

eval set -- "$opciones";

while true; do
    case "$1" in
        -d | --directorio)
            directorioEntrada="$2";
            shift 2;
            ;;
        -s | --salida)
            rutaArchivoSalida="$2";
            shift 2;
            ;;
        -p | --pantalla)
            mostrarPorPantalla=true;
            shift;
            ;;
        --)
            shift;
            break;
            ;;
        -h | --help)
            ayuda;
            exit 0;
            ;;
        *)
            echo "ERROR: Argumento desconocido: $1";
            exit $ERROR_ARGUMENTO_DESCONOCIDO;
            ;;
    esac
done

# Verificar que se haya proporcionado el directorio de entrada correctamente
if ! [ -d "$directorioEntrada" ]; then
    echo "ERROR: Se debe especificar un directorio válido que contenga los archivos CSV.";
    ayuda;
    exit $ERROR_DIRECTORIO;
fi

# Verificar que solo se haya proporcionado una opción de salida
if [ "$mostrarPorPantalla" = true ] && [ -n "$rutaArchivoSalida" ]; then
    echo "ERROR: No se puede especificar la opción de pantalla (-p | --pantalla) junto con la opción de salida (-s | --salida).";
    ayuda;
    exit $ERROR_ARCHIVO_SALIDA_Y_PANTALLA;
fi

# Verificar que se haya proporcionado la ruta de salida correctamente
if [ "$mostrarPorPantalla" = false ]; then
    
    # Verifico que la ruta de salida no sea un directorio
    if [ -d "$rutaArchivoSalida" ]; then
        echo "ERROR: La ruta del archivo de salida es un directorio.";
        ayuda;
        exit $ERROR_DIRECTORIO;
    fi

    # Verifico que la ruta de salida exista creando un archivo temporal
    touch "$rutaArchivoSalida" 2>/dev/null;
    
    if [ $? -ne 0 ]; then
        echo "ERROR: Se debe especificar una ruta válida para guardar el archivo JSON.";         
        ayuda;        
        exit $ERROR_RUTA_INVALIDA;     
    fi
    
    # Eliminar el archivo temporal si se creó
    rm -f "$rutaArchivoSalida";

    # Verifico que el archivo indicado en la ruta de salida tenga como extension JSON
    extension="${rutaArchivoSalida##*.}";

    extension="${extension,,}";

    if [ "$extension" != "json" ]; then
        echo "ERROR: En la ruta del archivo de salida se debe especificar que este tendra una extensión JSON.";
        ayuda;
        exit $ERROR_EXTENSION;
    fi

fi

# ================================= Ejecución =================================

main;
