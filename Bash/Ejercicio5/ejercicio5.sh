#!/bin/bash

# EJERCICIO 5
# - Manghi Scheck Santiago

#Flujo de datos:
#1)Ingresar parametros y valida que no tenga numeros ni caracter especial (excepto la ñ)
#2)Por cada parametro:
#2.1)Busca el personaje en el archivo json (cache). Si no lo encuentra, pide a la API
#2.2)Extrae los parametros y lo imprime en pantalla
#3) Si detecta clear elimina el archivo json (si existe).


#FORMATO:
#$ ./rickandmorty.sh --id “1,2” --nombre “rick, morty”

#-----------------------------<VARIABLES>-----------------------------
archivo_cache="archivo_cache.json"
declare -n nombres
declare -i id
declare -c clear_cache=false

#-----------------------------<FUNCIONES>-----------------------------

ayuda(){
cat <<'EOF'
NOMBRE
    rickandmorty.sh - Buscador de información de personajes de Rick and Morty

SINOPSIS
    rickandmorty.sh -n nombre(ES) [-i ID(ES)] [-clear] [-h]

DESCRIPCIÓN
    Consulta información de personajes de Rick and Morty utilizando la API y almacena
    los resultados en un archivo cache.json para evitar consultas repetidas. El archivo
    puede eliminarse mediante el comando -clear.

PARÁMETROS OBLIGATORIOS
    -n, --nombre PERSONAJE(S)
        Nombre(s) de los personajes a buscar. Múltiples nombres se separan por comas.
        Ejemplo: "rick,morty,summer"
    -i, --id ID(ES)
        ID(s) de los personajes a buscar. Múltiples IDs se separan por comas.
        Ejemplo: "1,2,3"


PARÁMETROS OPCIONALES
    -clear
        Elimina el archivo cache.json si existe.
    -h, --help
        Muestra esta ayuda y sale.

EJEMPLOS
    ./rickandmorty.sh -n rick -i 1
    ./rickandmorty.sh --nombre morty,summer --id 2,3
    ./rickandmorty.sh -clear
EOF
}

# Consulta API
consultar_api() {
    local personaje="$1"
     local url="https://rickandmortyapi.com/api/character/?name=${nombre_encoded}"
    local resultadoAPI
    resultadoAPI=$(curl -s -f "$url")
    local curl_exit_code=$?
    
    if [[ $curl_exit_code -ne 0 ]] || [[ -z "$resultadoAPI" ]]; then
        echo "Error: No se pudo conectar a la API para '$personaje'." >&2
        return 1
    fi

    local total=$(echo "$resultadoAPI" | jq -r '.results | length' 2>/dev/null)
    
      if [[ -z "$total" ]] || [[ "$total" == "0" ]] || [[ "$total" == "null" ]]; then
        echo "Error: No se encontró ningún personaje con el nombre '$nombre'." >&2
        return 1
    fi
    
    echo "$resultadoAPI" | jq '(.results)[0]'
}

#-----------------------------<PROGRAMA>-----------------------------

# Crear archivo de caché si no existe
[[ ! -f "$archivo_cache" ]] && echo "{}" > "$archivo_cache"

# Parsear parámetros
options=$(getopt -o n:t:h --long nombre:,ttl:,help -- "$@" 2>/dev/null)
if [[ $? -ne 0 ]]; then
    echo 'Opciones incorrectas. Use -h para ayuda.'
    exit 1
fi

eval set -- "$options"
while true; do
    case "$1" in
        -n|--nombre)
            IFS=',' read -r -a nombres <<< "$2"
            shift 2;;
        -h|--help)
            ayuda; exit 0;;
        --)
            shift; break;;
        *)
            echo "Error en parámetros"; exit 1;;
    esac
done

# Validaciones
if [[ ${#nombres[@]} -eq 0 ]]; then
    echo "Error: Debe ingresar al menos un país con -n" >&2
    exit 1
fi

for nombre in "${nombres[@]}"; do
    nombre=$(echo "$nombre" | xargs)  

    if ! [[ "$nombre" =~ ^[a-zA-ZñÑáéíóúÁÉÍÓÚ[:space:]-]+$ ]]; then
        echo "Error: El nombre del país '$nombre' solo puede contener letras y espacios." >&2
        continue
    fi
 # Consultar cache
    if resultado=$(consultar_cache "$nombre"); then
        echo "Datos desde caché:"
    else # Consulto API
        echo "Consultando API para '$nombre'..."
        if resultado=$(consultar_api "$nombre"); then
            guardar_cache "$nombre" "$resultado"
        else
            continue
        fi
    fi

  # Extraigo los campos y los imprimo
    id=$(echo "$resultado" | jq -r '.id')
    nombre=$(echo "$resultado" | jq -r '.name')
    status=$(echo "$resultado" | jq -r '.status')
    species=$(echo "$resultado" | jq -r '.species')
    gender=$(echo "$resultado" | jq -r '.gender')
    origin=$(echo "$resultado" | jq -r '.origin.name')
    location=$(echo "$resultado" | jq -r '.location.name')
    episodes=$(echo "$resultado" | jq -r '.episode | length')

    echo "  Nombre: $nombre"
    echo "  ID: $id"
    echo "  Status: $status"
    echo "  Species: $species"
    echo "  Gender: $gender"
    echo "  Origin: $origin"
    echo "  Location: $location"
    echo "  Episodes: $episodes"
done