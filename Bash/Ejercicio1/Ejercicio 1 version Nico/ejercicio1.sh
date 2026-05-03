#!/bin/bash

# =============================================================================
# INTEGRANTES DEL GRUPO
# =============================================================================
# Integrente 1: Masino, Carlos Nicolás — DNI: 42855529
# Integrante 2: Chavez, Christian      — DNI: 94529742
# Integrante 3: Apellido Nombre        — DNI: XXXXX
# Integrante 4: Apellido Nombre        — DNI: XXXXX
# =============================================================================
 

# Lo siguiente fue creado en base ciertas sintaxis que aparecen que vale la pena mencionar de cara a entender el funcionamiento del script.
# =============================================================================
# NOMENCLATURA Y REFERENCIA DE SINTAXIS BASH / AWK
# =============================================================================
#
# ── VARIABLES ─────────────────────────────────────────────────────────────────
#   local VAR           Variable local: su scope esta limitado exclusivamente
#                       a la funcion donde se declara. No es visible fuera.
#
#   ${!i}               Indireccion: expande el argumento posicional en la
#                       posicion $i. Si i=3, ${!i} equivale a $3.
#
# ── OPERADORES DE CONDICION ───────────────────────────────────────────────────
#   [[ $i -gt $# ]] && error_salir "msg" 
#   
#   Esto basicamente es: "Condicion && comando": si la condicion es verdadera,
#                                     ejecuta lo que esta a la derecha del &&.
#
# ── REDIRECCION ───────────────────────────────────────────────────────────────
#   >&2                 Redirige stdout hacia stderr. Se usa para mensajes de
#                       error que no deben mezclarse con la salida normal.
#
# ── AWK ───────────────────────────────────────────────────────────────────────
#   SUBSEP              Caracter especial que AWK usa para separar datos en
#                       arrays multi-dimensionales. Permite unir varios valores
#                       en una sola celda sin que se confundan con comas u
#                       otros separadores del CSV.
#
# ── OPERADORES DE ARCHIVOS (dentro de [[ ]]) ─────────────────────────────────
#   -z "$var"           Verdadero si el string esta vacío
#                       ("¿se especifico el archivo?")
#   -n "$var"           Verdadero si el string NO esta vacío
#   -e "$ruta"          Verdadero si la ruta existe (archivo, dir, symlink…)
#                       ("¿existe este archivo o ruta?")
#   -f "$ruta"          Verdadero si es un archivo regular (no directorio)
#                       ("¿es un archivo regular?")
#   -r "$ruta"          Verdadero si el proceso tiene permiso de lectura
#                       ("¿puedo leer este archivo?")
#
# ── PARAMETER EXPANSION ──────────────────────────────────────────────────────
#   ${var,,}            Convierte TODO el contenido de $var a minusculas
#   ${var^^}            Convierte TODO el contenido de $var a MAYUSCULAS
#   ${var^}             Convierte solo la PRIMERA letra a mayuscula
#   ${var#prefijo}      Elimina el prefijo más corto que coincida con "prefijo"
#                       (usado aqui para quitar "CONT=", "SUM=", etc.)
#
# =============================================================================


# =============================================================================
# ejercicio1.sh — Procesador genérico de archivos CSV
#
# Permite filtrar registros por campo/patron y realizar operaciones de
# conteo o suma sobre cualquier campo del CSV.
#
# Uso:
#   ./ejercicio1.sh -a <archivo.csv> [-f <campo>] [-b <patron>] (-c | -s <campo>) [-n <N>]
#   ./ejercicio1.sh --archivo <archivo.csv> [--filtro <campo>] [--buscar <patron>]
#                 (--contar | --sumar <campo>) [--numero <N>]
#
# Parámetros:
#   -a, --archivo  Archivo CSV de entrada (obligatorio)
#   -f, --filtro   Campo por el que filtrar (opcional)
#   -b, --buscar   Patron a buscar en el campo filtro (requerido si se usa -f)
#   -c, --contar   Contar registros coincidentes (excluyente con -s)
#   -s, --sumar    Nombre del campo a sumar (excluyente con -c)
#   -n, --numero   Cantidad de registros a mostrar en preview (0 = todos, default: 10)
#   -t, --test     Ejecutar bateria de pruebas automaticas
#   -h, --help     Mostrar esta ayuda
# =============================================================================

# ─── Colores ──────────────────────────────────────────────────────────────────
RESET='\033[0m'
NEGRO='\033[1m'
CYAN='\033[0;36m'
VERDE='\033[0;32m'
AMARILLO='\033[0;33m'
ROJO='\033[0;31m'
VIOLETA='\033[0;35m'
GRIS='\033[0;90m'
BLANCO='\033[0;97m'

# ─── Separadores ──────────────────────────────────────────────────────────────
SEP_DOBLE="══════════════════════════════════════════════════════"
SEP_SIMPLE="──────────────────────────────────────────────────────"

# ─── Variables globales ───────────────────────────────────────────────────────
CSV_FILE=""
CAMPO_FILTRO=""
PATRON_FILTRO=""
SUM_CAMPO=""
CONTAR=0
SUMAR=0
MAX_PREVIEW=10
MAX_PREVIEW_SET=0
TMP_FILE=""

# ─── Limpieza de temporales (trap) ────────────────────────────────────────────
# Se ejecuta SIEMPRE al salir: con exito, con error o con Ctrl+C
limpiar_temporales() {
    if [[ -n "$TMP_FILE" && -f "$TMP_FILE" ]]; then
        rm -f "$TMP_FILE" 2>/dev/null
    fi
}
trap limpiar_temporales EXIT

# =============================================================================
# FUNCIONES
# =============================================================================

# ─── Mostrar ayuda ────────────────────────────────────────────────────────────
mostrar_ayuda() {
    echo ""
    echo -e "${NEGRO}${CYAN}${SEP_DOBLE}${RESET}"
    echo -e "${NEGRO}${BLANCO}  ejercicio1.sh — Procesador genérico de CSV${RESET}"
    echo -e "${NEGRO}${CYAN}${SEP_DOBLE}${RESET}"
    echo ""
    echo -e "${BLANCO}  Uso:${RESET}"
    echo -e "    ${AMARILLO}./ejercicio1.sh -a <archivo.csv> [-f <campo>] [-b <patrón>] (-c | -s <campo>) [-n <N>]${RESET}"
    echo ""
    echo -e "${BLANCO}  Parámetros:${RESET}"
    echo -e "    ${CYAN}-a${RESET}, ${CYAN}--archivo${RESET}   Archivo CSV de entrada ${ROJO}(obligatorio)${RESET}"
    echo -e "    ${CYAN}-f${RESET}, ${CYAN}--filtro${RESET}    Campo por el que filtrar ${GRIS}(opcional)${RESET}"
    echo -e "    ${CYAN}-b${RESET}, ${CYAN}--buscar${RESET}    Patron a buscar en el campo filtro ${GRIS}(requerido si se usa -f/--filtro)${RESET}"
    echo -e "    ${CYAN}-c${RESET}, ${CYAN}--contar${RESET}    Contar registros coincidentes ${GRIS}(excluyente con -s)${RESET}"
    echo -e "    ${CYAN}-s${RESET}, ${CYAN}--sumar${RESET}     Nombre del campo a sumar ${GRIS}(excluyente con -c)${RESET}"
    echo -e "    ${CYAN}-n${RESET}, ${CYAN}--numero${RESET}    Registros a mostrar en el preview ${GRIS}(0 = todos, default: 10)${RESET}"
     echo -e "    ${CYAN}-p${RESET}, ${CYAN}--extra${RESET}     Columnas extra a mostrar en el preview además del identificador y campos usados ${GRIS}(0 = ninguna, default: 0)${RESET}"
    echo -e "    ${CYAN}-t${RESET}, ${CYAN}--test${RESET}      Ejecutar lote de pruebas automaticas"
    echo -e "    ${CYAN}-h${RESET}, ${CYAN}--help${RESET}      Mostrar esta ayuda"
    echo ""
    echo -e "${BLANCO}  Ejemplos:${RESET}"
    echo -e "    ${GRIS}./ejercicio1.sh -a customers-100.csv -f Country -b \"United\" -c${RESET}"
    echo -e "    ${GRIS}./ejercicio1.sh -a customers-100.csv -f Country -b \"United\" -s Index${RESET}"
    echo -e "    ${GRIS}./ejercicio1.sh --archivo customers-100.csv --filtro \"First Name\" --buscar \"a\" --sumar Index${RESET}"
    echo -e "    ${GRIS}./ejercicio1.sh -a customers-100.csv -c -n 0${RESET}"
    echo -e "    ${GRIS}./ejercicio1.sh -a customers-100.csv -f Country -b \"United\" -c -p 2   ${RESET}${GRIS}# muestra 2 cols extra ademas de Index y Country${RESET}"
    echo -e "    ${GRIS}./ejercicio1.sh -a customers-100.csv -f Country -b \"United\" -c -p 0   ${RESET}${GRIS}# solo Index y Country, nada mas${RESET}"
    echo ""
    echo -e "${NEGRO}${CYAN}${SEP_DOBLE}${RESET}"
    echo ""
}

# ─── Mostrar error y salir ────────────────────────────────────────────────────
# Uso: error_salir "Mensaje de error"
error_salir() {
    local mensaje="$1"
    echo "" >&2
    echo -e "${ROJO}${NEGRO}  ✗ Error:${RESET} ${ROJO}${mensaje}${RESET}" >&2
    echo -e "${GRIS}  Use './ejercicio1.sh --help' para ver la ayuda.${RESET}" >&2
    echo "" >&2
    exit 1
}

# ─── Parseo de argumentos (soporta cortos, largos y valores con espacios) ─────
parsear_argumentos() {
    # Recorre los argumentos manualmente para soportar --param-largo y espacios
    local i=1
    while [[ $i -le $# ]]; do
        local arg="${!i}"
        case "$arg" in
            -a|--archivo)
                ((i++))
                [[ $i -gt $# ]] && error_salir "El parametro '$arg' requiere un valor (ruta al archivo CSV)."
                CSV_FILE="${!i}"
                ;;
            -f|--filtro)
                ((i++))
                [[ $i -gt $# ]] && error_salir "El parametro '$arg' requiere un valor (nombre del campo)."
                CAMPO_FILTRO="${!i}"
                ;;
            -b|--buscar)
                ((i++))
                [[ $i -gt $# ]] && error_salir "El parametro '$arg' requiere un valor (patron de búsqueda)."
                PATRON_FILTRO="${!i}"
                ;;
            -s|--sumar)
                ((i++))
                [[ $i -gt $# ]] && error_salir "El parametro '$arg' requiere un valor (nombre del campo a sumar)."
                SUM_CAMPO="${!i}"
                SUMAR=1
                ;;
            -c|--contar)
                CONTAR=1
                ;;
            -n|--numero)
                ((i++))
                [[ $i -gt $# ]] && error_salir "El parametro '$arg' requiere un valor numerico."
                MAX_PREVIEW="${!i}"
                MAX_PREVIEW_SET=1
                if ! [[ "$MAX_PREVIEW" =~ ^[0-9]+$ ]]; then
                    error_salir "El valor de '$arg' debe ser un numero entero mayor o igual a 0 (recibido: \"${MAX_PREVIEW}\")."
                fi
                ;;
            -p|--extra)
                ((i++))
                [[ $i -gt $# ]] && error_salir "El parámetro '$arg' requiere un valor numérico (cantidad de columnas extra)."
                PREVIEW_EXTRA="${!i}"
                if ! [[ "$PREVIEW_EXTRA" =~ ^[0-9]+$ ]]; then
                    error_salir "El valor de '$arg' debe ser un número entero mayor o igual a 0 (recibido: \"${PREVIEW_EXTRA}\")."
                fi
                ;;
            -h|--help)
                mostrar_ayuda
                exit 0
                ;;
            -*)
                error_salir "Opcion desconocida: '${arg}'. Use '--help' para ver los parametros disponibles."
                ;;
            *)
                error_salir "Argumento inesperado: '${arg}'. Use '--help' para ver los parametros disponibles."
                ;;
        esac
        ((i++))
    done
}

# ─── Validaciones ──────────────────────────────────────────────────
validar_argumentos() {
    # Parámetro obligatorio: archivo
    if [[ -z "$CSV_FILE" ]]; then
        error_salir "Debe especificar un archivo CSV con '-a' o '--archivo'."
    fi

    # El archivo debe existir y ser legible
    if [[ ! -e "$CSV_FILE" ]]; then
        error_salir "El archivo \"${CSV_FILE}\" no existe. Verifique la ruta e intente nuevamente."
    fi
    if [[ ! -f "$CSV_FILE" ]]; then
        error_salir "\"${CSV_FILE}\" no es un archivo válido (podría ser un directorio)."
    fi
    if [[ ! -r "$CSV_FILE" ]]; then
        error_salir "No se tiene permiso de lectura sobre el archivo \"${CSV_FILE}\"."
    fi

    # Suma y conteo son excluyentes
    if [[ $SUMAR -eq 1 && $CONTAR -eq 1 ]]; then
        error_salir "Las operaciones '--sumar' (-s) y '--contar' (-c) son excluyentes: use solo una de las dos."
    fi

    # Debe haber al menos una operacion
    if [[ $SUMAR -eq 0 && $CONTAR -eq 0 ]]; then
        error_salir "Debe especificar una operacion: '--contar' (-c) para contar registros, o '--sumar <campo>' (-s) para sumar un campo."
    fi

    # Si hay campo de filtro, debe haber patron (y viceversa)
    if [[ -n "$CAMPO_FILTRO" && -z "$PATRON_FILTRO" ]]; then
        error_salir "Se especifico el campo de filtro \"${CAMPO_FILTRO}\" pero falta el patron de búsqueda '--buscar' (-b)."
    fi
    if [[ -n "$PATRON_FILTRO" && -z "$CAMPO_FILTRO" ]]; then
        error_salir "Se especifico el patron \"${PATRON_FILTRO}\" pero falta el campo de filtro '--filtro' (-f)."
    fi
}

# ─── Parser de linea de cabecera CSV ─────────────────────────────────────────
# Lee la primera linea del CSV y devuelve los campos (uno por linea)
parsear_cabecera_csv() {
    local linea="$1"
    local campo=""
    local en_comillas=0
    local i=0
    local len=${#linea}
    local caract

    while [[ $i -lt $len ]]; do #Si i es menor al tamaño de la linea, entramos a while. Si el caracter es "(comillas) seteamos en_comillas = 1 e iteramos hasta el cierre de comillas.
        caract="${linea:$i:1}"  #Si no es comillas lo que leemos, verificamos si es , (coma) y con el valor de en_comillas verificamos si es un literal o separador de campo.
        if [[ "$caract" == '"' ]]; then
            if [[ $en_comillas -eq 1 && "${linea:$((i+1)):1}" == '"' ]]; then
                campo+='"'
                ((i++))
            elif [[ $en_comillas -eq 1 ]]; then
                en_comillas=0
            else
                en_comillas=1 
            fi
        elif [[ "$caract" == ',' && $en_comillas -eq 0 ]]; then
            printf '%s\n' "$campo"
            campo=""
        else
            campo+="$caract"
        fi
        ((i++))
    done
    printf '%s\n' "$campo"
}

# ─── Obtener indice (base 0) de un campo por nombre (insensible a mayusculas) ─
# Imprime el indice o -1 si no se encuentra
# Buscamos a que columna del header (encabezado) del CSV pertenece un determinado campo, es decir, su posicion.
obtener_indice_campo() {
    local target="${1,,}"   # lowercase
    local i=0
    for h in "${HEADERS[@]}"; do
        if [[ "${h,,}" == "$target" ]]; then
            echo "$i"
            return 0
        fi
        ((i++))
    done
    echo -1
}

# ─── Formatear número con separadores de miles (es decir .) ────────────────────────────────
formatear_numero() {
    printf "%'.0f" "$1" 2>/dev/null || printf "%s" "$1" #usa fallback, es decir, si falla lo imprime tal cual.
}

# ─── Construir la representación del comando ejecutado ────────────────────────
construir_cmd() {
    local cmd="./ejercicio1.sh"
    cmd+=" --archivo \"${CSV_FILE}\""
    [[ -n "$CAMPO_FILTRO" ]]     && cmd+=" --filtro \"${CAMPO_FILTRO}\""
    [[ -n "$PATRON_FILTRO" ]]   && cmd+=" --buscar \"${PATRON_FILTRO}\""
    [[ $CONTAR -eq 1 ]]        && cmd+=" --contar"
    [[ $SUMAR  -eq 1 ]]        && cmd+=" --sumar \"${SUM_CAMPO}\""
    [[ $MAX_PREVIEW_SET -eq 1 ]] && cmd+=" --numero ${MAX_PREVIEW}"
    echo "$cmd"
}

# ─── Procesar el CSV con AWK ──────────────────────────────────────────────────
# Escribe los resultados en TMP_FILE para evitar subshells y variables perdidas
procesar_csv() {
    local awk_max_preview
    if [[ "$MAX_PREVIEW" -eq 0 ]]; then
        awk_max_preview=999999999
    else
        awk_max_preview=$MAX_PREVIEW
    fi

    # Crear archivo temporal en /tmp (el trap se encarga de borrarlo al salir)
    TMP_FILE=$(mktemp /tmp/ejercicio1_XXXXXX) || \
        error_salir "No se pudo crear el archivo temporal en /tmp. Verifique los permisos del sistema."

    #CSV → parseo → filtro → conteo → suma → preview → salida 
    awk \
        -v filter_col="$FILTER_COL_IDX" \
        -v filter_pat="$PATRON_FILTRO" \
        -v suma="$SUMAR" \
        -v suma_col="$suma_col_IDX" \
        -v preview_cols_str="$PREVIEW_COLS_STR" \
        -v max_preview="$awk_max_preview" \
        '
        BEGIN {
            FS = ","  #Separador de columnas CSV
            CONT         = 0
            sum          = 0
            no_numerico  = 0
            preview_cont = 0

            # Parsear "0,1,2,3" → array preview_col_idx[0..n]
            num_preview_cols = split(preview_cols_str, preview_col_idx, ",")
        }

        function ltrim(s) { sub(/^[ \t]+/, "", s); return s }
        function rtrim(s) { sub(/[ \t]+$/, "", s); return s }
        function trim(s)  { return ltrim(rtrim(s)) }

        function quitar_comillas(s) {
            if (substr(s,1,1) == "\"" && substr(s,length(s),1) == "\"") {
                s = substr(s, 2, length(s)-2)
                gsub(/""/, "\"", s)
            }
            return s
        }

         # Parser CSV que respeta campos entre comillas (incluyendo comas internas)        # Por cada caracter, si es una comilla verifico si es una comilla literal (if) o no es literal (else)
        function parsear_linea(linea,   campos, f, n, en_comillas, caract, i) {
            n = 0; f = ""; en_comillas = 0
            for (i = 1; i <= length(linea); i++) {
                caract = substr(linea, i, 1)
                if (caract == "\"") {
                    if (en_comillas && substr(linea, i+1, 1) == "\"") { 
                        f = f "\""; i++ 
                    } else{
                        en_comillas = !en_comillas
                    }
                } else if (caract == "," && !en_comillas) {      # Si el caracter es una , (coma) entonces verifico si estoy o no en comillas para saber si es una coma literal (if) o no (else)
                    campos[n++] = trim(quitar_comillas(f)); f = ""
                } else {
                    f = f caract
                }
            }
            campos[n++] = trim(quitar_comillas(f))
            return n
        }

        NR == 1 { next }     #Saltar línea de cabecera

        {
            n = parsear_linea($0, cols)   # Llamo a funcion para parsear respetando comillas

            # Aplicar filtro si fue solicitado
            if (filter_col >= 0) {
                campo_filter = (filter_col < n) ? cols[filter_col] : ""
                if (index(tolower(campo_filter), tolower(filter_pat)) == 0) next     # Si no contiene el patrón de filtro entonces saltear la fila
            }

            CONT++

            # Guardar fila para el preview (hasta max_preview registros)         # Variables respetan nombre de headers de CSV para mayor claridad
            if (preview_cont < max_preview) {
                # Guardar hasta num_preview_cols valores, separados por SUBSEP
                fila = ""
                for (pc = 1; pc <= num_preview_cols; pc++) {
                    idx_col = preview_col_idx[pc] + 0   # índice base 0
                    val = (idx_col < n) ? cols[idx_col] : ""
                    fila = (pc == 1) ? val : fila SUBSEP val
                }
                preview[preview_cont] = fila       # SUBSEP es un caracter que AWK usa para separar datos internamente.
                preview_cont++                     # Se usa para unir varios valores en uno solo sin que se rompan despues
            }

            # Sumar campo si fue solicitado
            if (suma) {
                campo_sum = (suma_col >= 0 && suma_col < n) ? cols[suma_col] : "0"
                gsub(/,/, "", campo_sum)
                if (campo_sum ~ /^-?[0-9]+(\.[0-9]+)?$/) { sum += campo_sum + 0 }
                else { no_numerico++ }
            }
        }

        END {
            print "CONT="         CONT
            print "SUM="          sum
            print "NO_NUMERICO="  no_numerico      # Cuantos valores NO eran numeros (y no se pudieron sumar)
            print "PREVIEW_CONT=" preview_cont
            for (i = 0; i < preview_cont; i++) {
                num_partes = split(preview[i], partes, SUBSEP)
                linea = "PREVIEW"
                for (p = 1; p <= num_partes; p++) linea = linea "|" partes[p]
                print linea
            }
        }
        ' "$CSV_FILE" > "$TMP_FILE"

    # Verificar que awk no haya fallado
    local awk_exit=$?
    if [[ $awk_exit -ne 0 ]]; then
        error_salir "Ocurrió un problema al procesar el archivo CSV (awk terminó con código ${awk_exit}). Verifique que el archivo sea un CSV válido."
    fi
}

# ─── Leer resultados del archivo temporal ─────────────────────────────────────
leer_resultados() {
    CONT=0
    SUM=0
    NO_NUMERICO=0
    PREVIEW_CONT=0
    PREVIEW_FILAS=()

    while IFS= read -r linea; do  # IFS=  no recorta espacios | -r no interpreta \ como escape | linea → contiene cada línea del archivo
        case "$linea" in          # Lee desde arch temporal y elimina el prefijo "CONT=", "SUM=", etc
            CONT=*)         CONT="${linea#CONT=}" ;;
            SUM=*)           SUM="${linea#SUM=}" ;;
            NO_NUMERICO=*)   NO_NUMERICO="${linea#NO_NUMERICO=}" ;;
            PREVIEW_CONT=*) PREVIEW_CONT="${linea#PREVIEW_CONT=}" ;;
            PREVIEW|*)       PREVIEW_FILAS+=("${linea#PREVIEW|}") ;;
        esac
    done < "$TMP_FILE"
}

# ─── Imprimir cabecera del output ─────────────────────────────────────────────
imprimir_cabecera() {
    local cmd="$1"

    echo ""
    echo -e "${NEGRO}${CYAN}${SEP_DOBLE}${RESET}"
    echo -e "${NEGRO}${BLANCO}  CSV PROCESSOR — ejercicio1.sh${RESET}"
    echo -e "${NEGRO}${CYAN}${SEP_DOBLE}${RESET}"
    echo ""
    echo -e "${GRIS}  \$${RESET} ${AMARILLO}${cmd}${RESET}"
    echo ""
    echo -e "${CYAN}${SEP_SIMPLE}${RESET}"
    echo -e "  ${BLANCO}Archivo    :${RESET} ${VERDE}${CSV_FILE}${RESET}"
    echo -e "  ${BLANCO}Campos CSV :${RESET} ${GRIS}${NUM_HEADERS} campos detectados${RESET}"

    if [[ -n "$CAMPO_FILTRO" ]]; then
        echo -e "  ${BLANCO}Filtro     :${RESET} ${CYAN}${CAMPO_FILTRO}${RESET} contiene ${AMARILLO}\"${PATRON_FILTRO}\"${RESET}"
    else
        echo -e "  ${BLANCO}Filtro     :${RESET} ${GRIS}(ninguno — actúa sobre todos los registros)${RESET}"
    fi

    if [[ $CONTAR -eq 1 ]]; then
        echo -e "  ${BLANCO}Operación  :${RESET} ${VIOLETA}CONTAR registros${RESET}"
    else
        echo -e "  ${BLANCO}Operación  :${RESET} ${VIOLETA}SUMAR${RESET} campo ${CYAN}\"${SUM_CAMPO}\"${RESET}"
    fi

    if [[ $MAX_PREVIEW_SET -eq 1 ]]; then
        if [[ "$MAX_PREVIEW" -eq 0 ]]; then
            echo -e "  ${BLANCO}Preview    :${RESET} ${GRIS}mostrar TODOS los registros coincidentes${RESET}"
        else
            echo -e "  ${BLANCO}Preview    :${RESET} ${GRIS}mostrar hasta ${MAX_PREVIEW} registros${RESET}"
        fi
    else
        echo -e "  ${BLANCO}Preview    :${RESET} ${GRIS}mostrando hasta 10 registros (use -n N para cambiar, -n 0 para todos)${RESET}"
    fi
    # Mostrar qué columnas se van a ver en el preview
    if [[ $PREVIEW_EXTRA -ge 0 ]]; then
        echo -e "  ${BLANCO}Columnas   :${RESET} ${GRIS}campos base + ${PREVIEW_EXTRA} extra(s) → ${CYAN}${PREVIEW_NOMBRES[*]}${RESET}"
    else
        echo -e "  ${BLANCO}Columnas   :${RESET} ${GRIS}solo campos usados → ${CYAN}${PREVIEW_NOMBRES[*]}${RESET}"
    fi

    echo -e "${CYAN}${SEP_SIMPLE}${RESET}"
    echo ""
}

# ─── Imprimir tabla de resultados ─────────────────────────────────────────────
imprimir_resultados() {
    if [[ $CONT -eq 0 ]]; then
        echo -e "  ${AMARILLO}⚠  No se encontraron registros que coincidan con los criterios indicados.${RESET}"
        if [[ -n "$CAMPO_FILTRO" ]]; then
            echo -e "  ${GRIS}   (El campo \"${CAMPO_FILTRO}\" no contiene \"${PATRON_FILTRO}\" en ningún registro del archivo)${RESET}"
        fi
        echo ""
        echo -e "${CYAN}${SEP_SIMPLE}${RESET}"
        echo -e "  ${NEGRO}${VIOLETA}Resultado  : 0${RESET}"
    else
        local show=$PREVIEW_CONT

        if [[ "$MAX_PREVIEW" -eq 0 ]]; then
            echo -e "  ${BLANCO}Registros coincidentes${RESET} ${GRIS}(mostrando todos — ${CONT} en total):${RESET}"
        elif [[ $CONT -le $MAX_PREVIEW ]]; then
            echo -e "  ${BLANCO}Registros coincidentes${RESET} ${GRIS}(${CONT} en total):${RESET}"
        else
            echo -e "  ${BLANCO}Registros coincidentes${RESET} ${GRIS}(mostrando ${show} de ${CONT}):${RESET}"
        fi

        echo ""
        # ── Calcular ancho de cada columna segun el contenido real ────────────
        # Empezamos con el ancho del nombre del header como minimo.
        # Luego recorremos todas las filas del preview y si algun valor es mas
        # largo, ese pasa a ser el nuevo ancho para esa columna.
        local -a col_anchos=()
        local ci
        for (( ci=0; ci<${#PREVIEW_NOMBRES[@]}; ci++ )); do
            col_anchos[$ci]=${#PREVIEW_NOMBRES[$ci]}
        done

        for fila in "${PREVIEW_FILAS[@]}"; do
            IFS='|' read -r -a partes <<< "$fila"
            for (( ci=0; ci<${#PREVIEW_NOMBRES[@]}; ci++ )); do
                local val="${partes[$ci]:-}"
                [[ ${#val} -gt ${col_anchos[$ci]} ]] && col_anchos[$ci]=${#val}
            done
        done

        # ── Imprimir encabezado con anchos calculados ─────────────────────────
        local tabla_ancho=2   # sangria inicial de "  "
        for (( ci=0; ci<${#PREVIEW_NOMBRES[@]}; ci++ )); do
            tabla_ancho=$(( tabla_ancho + col_anchos[ci] + 2 ))
        done

        # Ancho real de la terminal; si tput no esta disponible usar 120 como fallback
        local term_ancho
        term_ancho=$(tput cols 2>/dev/null) || term_ancho=120

        # Modo vertical si la tabla no entra en la terminal
        local modo_vertical=0
        [[ $tabla_ancho -gt $term_ancho ]] && modo_vertical=1

        # Ancho maximo del nombre de campo, para alinear los ":" en modo vertical
        local max_nombre=0
        for nombre in "${PREVIEW_NOMBRES[@]}"; do
            [[ ${#nombre} -gt $max_nombre ]] && max_nombre=${#nombre}
        done

        if [[ $modo_vertical -eq 1 ]]; then
            # ── MODO VERTICAL ─────────────────────────────────────────────────
            local num_reg=0
            for fila in "${PREVIEW_FILAS[@]}"; do
                IFS='|' read -r -a partes <<< "$fila"
                ((num_reg++))
                echo -e "  ${GRIS}── Registro ${num_reg} $( printf '─%.0s' $(seq 1 $((max_nombre + 20))) )${RESET}"
                for (( ci=0; ci<${#PREVIEW_NOMBRES[@]}; ci++ )); do
                    local nombre="${PREVIEW_NOMBRES[$ci]}"
                    local val="${partes[$ci]:-}"
                    printf "  ${CYAN}%-${max_nombre}s${RESET}  %s\n" "$nombre" "$val"
                done
                echo ""
            done
        else
            # ── MODO TABLA HORIZONTAL ─────────────────────────────────────────
            # Encabezado
            local header_line="  "
            for (( ci=0; ci<${#PREVIEW_NOMBRES[@]}; ci++ )); do
                local ancho=${col_anchos[$ci]}
                local nombre="${PREVIEW_NOMBRES[$ci]^^}"   # ${var^^} → mayusculas
                header_line+=$(printf "${GRIS}%-${ancho}s${RESET}  " "$nombre")
            done
            echo -e "$header_line"

            # # Separador con longitud exacta al total de columnas
            local sep_len=0
            for (( ci=0; ci<${#PREVIEW_NOMBRES[@]}; ci++ )); do
                sep_len=$(( sep_len + col_anchos[ci] + 2 ))
            done
            # Separador
            local sep_line="  "
            for (( s=0; s<sep_len; s++ )); do sep_line+="─"; done
            echo -e "${GRIS}${sep_line}${RESET}"

            # ── Imprimir filas ────────────────────────────────────────────────────
            for fila in "${PREVIEW_FILAS[@]}"; do
                IFS='|' read -r -a partes <<< "$fila"
                local row_line="  "
                for (( ci=0; ci<${#PREVIEW_NOMBRES[@]}; ci++ )); do
                    local ancho=${col_anchos[$ci]}
                    local val="${partes[$ci]:-}"
                    row_line+=$(printf "%-${ancho}s  " "$val")
                done
                echo -e "$row_line"
            done
        fi

        if [[ $CONT -gt $show ]]; then
            local faltante=$(( CONT - show ))
            echo ""
            echo -e "  ${GRIS}  ··· y ${faltante} registros mas  (use ${AMARILLO}--numero ${CONT}${GRIS} o ${AMARILLO}--numero 0${GRIS} para verlos todos)${RESET}"
        fi

        echo ""
        echo -e "${CYAN}${SEP_SIMPLE}${RESET}"

        if [[ $CONTAR -eq 1 ]]; then
            echo -e "  ${NEGRO}${VERDE}✔${RESET}  ${NEGRO}${BLANCO}TOTAL REGISTROS CONTADOS :${RESET} ${NEGRO}${VIOLETA}${CONT}${RESET}"
        else
            # Formatear suma
            local sum_fmt
            if [[ "$SUM" =~ ^-?[0-9]+\.0+$ ]]; then
                sum_fmt=$(printf "%.0f" "$SUM")
            elif [[ "$SUM" =~ ^-?[0-9]+\.[0-9]*$ ]]; then
                sum_fmt=$(printf "%.2f" "$SUM")
            else
                sum_fmt="$SUM"
            fi
            local sum_formatted
            sum_formatted=$(formatear_numero "$sum_fmt")

            echo -e "  ${NEGRO}${VERDE}✔${RESET}  ${NEGRO}${BLANCO}SUMA DE \"${SUM_CAMPO}\" :${RESET} ${NEGRO}${VIOLETA}${sum_formatted}${RESET}"
            if [[ $NO_NUMERICO -gt 0 ]]; then
                echo -e "  ${AMARILLO}⚠  Nota: ${NO_NUMERICO} valor(es) no numerico(s) en el campo \"${SUM_CAMPO}\" fueron omitidos de la suma.${RESET}"
            fi
        fi
    fi

    echo ""
    echo -e "${NEGRO}${CYAN}${SEP_DOBLE}${RESET}"
    echo ""
}

# =============================================================================
# LOTE DE PRUEBAS AUTOMATICAS
# =============================================================================
#
# Crea un CSV temporal de prueba con datos conocidos y ejecuta 15 casos
# distintos, verificando si el script retorna el código de salida esperado
# (0 = exito, distinto de 0 = error).
#
# Cada prueba indica:
#   - Descripción del caso
#   - Si se espera que sea VALIDA (exit 0) o INVALIDA (exit != 0)
#   - El resultado real obtenido
# =============================================================================
 
ejecutar_tests() {
    # ── Colores locales — se usa $'...' para que bash interprete \033 como ESC ──
    local R=$'\033[0m'    NEG=$'\033[1m'    CYN=$'\033[0;36m'  VRD=$'\033[0;32m'
    local AMR=$'\033[0;33m' RJO=$'\033[0;31m' VLT=$'\033[0;35m' GRS=$'\033[0;90m' BLC=$'\033[0;97m'
 
    local SEP_D="══════════════════════════════════════════════════════"
    local SEP_S="──────────────────────────────────────────────────────"
 
    # ── Crear CSV de prueba temporal ──────────────────────────────────────────
    local CSV_TEST
    CSV_TEST=$(mktemp /tmp/ejercicio1_test_XXXXXX.csv) || {
        echo -e "${RJO}No se pudo crear el CSV temporal de prueba.${R}" >&2
        exit 1
    }
 
    # CSV con campos: Index,First Name,Last Name,Country,City,Amount
    cat > "$CSV_TEST" << 'EOF'
Index,First Name,Last Name,Country,City,Amount
1,John,Doe,United States,New York,150
2,Jane,Smith,United Kingdom,London,200
3,Carlos,García,Argentina,Buenos Aires,300
4,Maria,Lopez,United States,Los Angeles,50
5,Luca,Rossi,Italy,Rome,abc
6,Anna,Müller,Germany,Berlin,400
7,James,Brown,United Kingdom,Manchester,100
8,Sofia,Herrera,Argentina,Córdoba,250
9,William,Taylor,United States,Chicago,75
10,Yuki,Tanaka,Japan,Tokyo,500
EOF
 
    # ── Función interna para correr una prueba ────────────────────────────────
    # Uso: _run_test <numero> <descripcion> <esperado: VALIDA|INVALIDA> <args...>
    local pass=0
    local fail=0
    local total=0
 
    _run_test() {
        local num="$1"
        local desc="$2"
        local esperado="$3"
        shift 3
 
        ((total++))
 
        # Ejecutar el flujo principal en un subshell aislado.
        # Se llama a main() directamente (definida más abajo) para evitar
        # que bash "$0" vuelva a entrar en modo --test y siempre devuelva 0.
        ( main "$@" ) > /dev/null 2>&1
        local exit_code=$?
 
        local es_valida=0
        [[ $exit_code -eq 0 ]] && es_valida=1
 
        local ok=0
        if [[ "$esperado" == "VALIDA" && $es_valida -eq 1 ]]; then ok=1
        elif [[ "$esperado" == "INVALIDA" && $es_valida -eq 0 ]]; then ok=1
        fi
 
        local tag_esperado tag_resultado icono
        if [[ "$esperado" == "VALIDA" ]]; then
            tag_esperado="${VRD}VALIDA${R}"
        else
            tag_esperado="${RJO}INVALIDA${R}"
        fi
 
        if [[ $es_valida -eq 1 ]]; then
            tag_resultado="${VRD}exit 0${R}"
        else
            tag_resultado="${RJO}exit ${exit_code}${R}"
        fi
 
        if [[ $ok -eq 1 ]]; then
            icono="${VRD}✔ EXITO${R}"
            ((pass++))
        else
            icono="${RJO}✘ FALLO${R}"
            ((fail++))
        fi
 
        printf "  ${GRS}[%02d]${R} ${BLC}%-52s${R}  Esperado:%-10s  Obtenido:%-10s  %b\n" \
            "$num" "$desc" "$tag_esperado" "$tag_resultado" "$icono"
    }
 
 
    # ── Encabezado ────────────────────────────────────────────────────────────
    echo ""
    echo -e "${NEG}${CYN}${SEP_D}${R}"
    echo -e "${NEG}${BLC}  ejercicio1.sh — Lote de Pruebas Automáticas${R}"
    echo -e "${NEG}${CYN}${SEP_D}${R}"
    echo ""
    echo -e "  ${GRS}CSV de prueba: ${AMR}${CSV_TEST}${R}"
    echo -e "  ${GRS}Campos: Index, First Name, Last Name, Country, City, Amount${R}"
    echo -e "  ${GRS}10 registros · 'Amount' tiene 1 valor no numérico (fila 5: 'abc')${R}"
    echo ""
    echo -e "  ${CYN}${SEP_S}${R}"
    printf "  ${GRS}%-4s  %-52s  %-16s  %-12s  %s${R}\n" \
        "NUM" "DESCRIPCIÓN" "ESPERADO" "OBTENIDO" "RESULTADO"
    echo -e "  ${CYN}${SEP_S}${R}"
 
    # =========================================================================
    # PRUEBAS VALIDAS (se espera exit 0)
    # =========================================================================
 
    # 01 — Contar todos los registros sin filtro
    _run_test 1 "Contar todos los registros (sin filtro)" \
        "VALIDA" -a "$CSV_TEST" -c
 
    # 02 — Contar con filtro por Country = "United"
    _run_test 2 "Contar: filtro Country contiene 'United'" \
        "VALIDA" -a "$CSV_TEST" -f "Country" -b "United" -c
 
    # 03 — Sumar campo 'Index' sin filtro
    _run_test 3 "Sumar campo 'Index' sin filtro" \
        "VALIDA" -a "$CSV_TEST" -s "Index" -n 0
 
    # 04 — Sumar campo 'Amount' con filtro (incluye valor no numérico)
    _run_test 4 "Sumar 'Amount' con filtro Argentina (aviso no numérico)" \
        "VALIDA" -a "$CSV_TEST" -f "Country" -b "Argentina" -s "Amount"
 
    # 05 — Parámetros en forma larga (--archivo, --contar, etc.)
    _run_test 5 "Usar parámetros en forma larga --archivo --contar" \
        "VALIDA" --archivo "$CSV_TEST" --contar
 
    # 06 — Filtro por nombre con patron en minúsculas (case-insensitive)
    _run_test 6 "Filtro 'First Name' busca 'john' (case-insensitive)" \
        "VALIDA" -a "$CSV_TEST" -f "First Name" -b "john" -c
 
    # 07 — Preview limitado a 3 registros
    _run_test 7 "Contar todos los registros, preview -n 3" \
        "VALIDA" -a "$CSV_TEST" -c -n 3
 
    # 08 — Preview con -n 0 (mostrar todos)
    _run_test 8 "Contar con -n 0 (mostrar todos en preview)" \
        "VALIDA" -a "$CSV_TEST" -c -n 0
 
    # 09 — Filtro que no devuelve ningún resultado (patron inexistente)
    _run_test 9 "Contar con filtro que no coincide con nada" \
        "VALIDA" -a "$CSV_TEST" -f "Country" -b "Wakanda" -c
 
    # 10 — Sumar campo numérico 'Amount' sobre todos los registros
    _run_test 10 "Sumar 'Amount' sin filtro (1 valor no numérico esperado)" \
        "VALIDA" -a "$CSV_TEST" -s "Amount"
 
    # =========================================================================
    # PRUEBAS INVALIDAS (se espera exit != 0)
    # =========================================================================
 
    # 11 — Sin parametro obligatorio -a/--archivo
    _run_test 11 "Sin parametro obligatorio -a (debe fallar)" \
        "INVALIDA" -c
 
    # 12 — Archivo que no existe
    _run_test 12 "Archivo inexistente (debe fallar)" \
        "INVALIDA" -a "/tmp/archivo_que_no_existe_XXXXX.csv" -c
 
    # 13 — Usar -c y -s al mismo tiempo (excluyentes)
    _run_test 13 "-c y -s juntos son excluyentes (debe fallar)" \
        "INVALIDA" -a "$CSV_TEST" -c -s "Index"
 
    # 14 — Filtro sin patron -b (campo sin busqueda)
    _run_test 14 "-f sin -b: campo filtro sin patron (debe fallar)" \
        "INVALIDA" -a "$CSV_TEST" -f "Country" -c
 
    # 15 — Campo de suma que no existe en el CSV
    _run_test 15 "Campo --sumar inexistente en el CSV (debe fallar)" \
        "INVALIDA" -a "$CSV_TEST" -s "SalarioCampoFalso" -n 5
 
    # ── Resumen ───────────────────────────────────────────────────────────────
    echo -e "  ${CYN}${SEP_S}${R}"
    echo ""
    echo -e "  ${BLC}Resultado final:${R}  ${VRD}${pass} pasaron${R}  /  ${RJO}${fail} fallaron${R}  /  ${GRS}${total} total${R}"
    echo ""
 
    if [[ $fail -eq 0 ]]; then
        echo -e "  ${NEG}${VRD}✔  Todas las pruebas pasaron correctamente.${R}"
    else
        echo -e "  ${NEG}${RJO}✘  ${fail} prueba(s) fallaron — revisar los casos marcados con ✘ INVALIDA.${R}"
    fi
 
    echo ""
    echo -e "${NEG}${CYN}${SEP_D}${R}"
    echo ""
 
    # Limpiar CSV temporal de prueba
    rm -f "$CSV_TEST" 2>/dev/null
}


# =============================================================================
# FLUJO PRINCIPAL
# =============================================================================

main() {
# 1. Sin argumentos → mostrar ayuda
if [[ $# -eq 0 ]]; then
    mostrar_ayuda
    exit 0
fi

# 2. Parsear argumentos (en cualquier orden, cortos y largos)
parsear_argumentos "$@"

# 3. Validar argumentos
validar_argumentos

# 4. Leer cabecera del CSV
header_linea=$(head -1 "$CSV_FILE") || \
    error_salir "No se pudo leer la cabecera del archivo \"${CSV_FILE}\". Verifique que sea un CSV válido y no esté vacío."

mapfile -t HEADERS < <(parsear_cabecera_csv "$header_linea")
NUM_HEADERS=${#HEADERS[@]}

if [[ $NUM_HEADERS -eq 0 ]]; then
    error_salir "No se encontraron campos en la cabecera del CSV. Verifique que el archivo tenga formato válido."
fi

# 5. Validar que los campos indicados existan en el CSV
FILTER_COL_IDX=-1
if [[ -n "$CAMPO_FILTRO" ]]; then
    FILTER_COL_IDX=$(obtener_indice_campo "$CAMPO_FILTRO")
    if [[ $FILTER_COL_IDX -eq -1 ]]; then
        echo "" >&2
        echo -e "${ROJO}${NEGRO}  ✗ Error:${RESET} ${ROJO}El campo de filtro \"${CAMPO_FILTRO}\" no existe en el CSV.${RESET}" >&2
        echo -e "${GRIS}  Campos disponibles: ${HEADERS[*]}${RESET}" >&2
        echo -e "${GRIS}  Use '--help' para ver la ayuda.${RESET}" >&2
        echo "" >&2
        exit 1
    fi
fi

suma_col_IDX=-1
if [[ $SUMAR -eq 1 ]]; then
    suma_col_IDX=$(obtener_indice_campo "$SUM_CAMPO")
    if [[ $suma_col_IDX -eq -1 ]]; then
        echo "" >&2
        echo -e "${ROJO}${NEGRO}  ✗ Error:${RESET} ${ROJO}El campo de suma \"${SUM_CAMPO}\" no existe en el CSV.${RESET}" >&2
        echo -e "${GRIS}  Campos disponibles: ${HEADERS[*]}${RESET}" >&2
        echo -e "${GRIS}  Use '--help' para ver la ayuda.${RESET}" >&2
        echo "" >&2
        exit 1
    fi
fi

# 6. Resolver columnas para el preview de forma contextual:
    #    Siempre: col 0 (identificador) + campo de filtro + campo de suma, sin duplicados y en ese orden de prioridad.
    #    Columnas EXTRA: controladas por -p/--extra (default 0).
    #    Solo se agregan extras que realmente existan y no esten ya incluidas.

    PREVIEW_COLS=()
    PREVIEW_NOMBRES=()

    # Funcion interna: agrega un indice al preview solo si no esta ya incluido
    _agregar_col_preview() {
        local idx="$1"
        local nombre="$2"
        local ya
        for ya in "${PREVIEW_COLS[@]}"; do
            [[ "$ya" == "$idx" ]] && return   # ya esta, no duplicar
        done
        PREVIEW_COLS+=("$idx")
        PREVIEW_NOMBRES+=("$nombre")
    }

    # Columnas base: siempre col 0, luego filtro y/o suma si se usaron
    # EXCEPCIÓN: si es -c sin filtro ni suma → mostrar todas las columnas
    # del CSV para que el registro completo sea visible.
    if [[ $CONTAR -eq 1 && $FILTER_COL_IDX -eq -1 && $suma_col_IDX -eq -1 ]]; then
        for (( _ci=0; _ci<NUM_HEADERS; _ci++ )); do
            _agregar_col_preview "$_ci" "${HEADERS[$_ci]}"
        done
    else
        _agregar_col_preview "0" "${HEADERS[0]}"

        # 2) Campo de filtro (si se uso)
        [[ $FILTER_COL_IDX -ge 0 ]] && _agregar_col_preview "$FILTER_COL_IDX" "$CAMPO_FILTRO"

        # 3) Campo de suma (si se uso)
        [[ $suma_col_IDX -ge 0 ]] && _agregar_col_preview "$suma_col_IDX" "$SUM_FIELD"

        # Columnas extra: recorrer el header en orden y agregar las primeras
        # PREVIEW_EXTRA columnas que no esten ya incluidas.
        # Si PREVIEW_EXTRA == -1 (no se paso -p) el default es 0 extras.
        local extras_a_agregar=0
        [[ $PREVIEW_EXTRA -ge 0 ]] && extras_a_agregar=$PREVIEW_EXTRA

        local extras_agregadas=0
        local _ei=0
        while [[ $_ei -lt $NUM_HEADERS && $extras_agregadas -lt $extras_a_agregar ]]; do
            # _agregar_col_preview ya ignora duplicados, pero necesitamos contar
            # solo las que realmente se agregaron → guardamos el tamaño antes
            local antes=${#PREVIEW_COLS[@]}
            _agregar_col_preview "$_ei" "${HEADERS[$_ei]}"
            local despues=${#PREVIEW_COLS[@]}
            [[ $despues -gt $antes ]] && ((extras_agregadas++))
            ((_ei++))
        done
    fi

    # String "0,2,3" (o los que sean) para pasarlo como variable a awk 
    PREVIEW_COLS_STR=$(IFS=','; echo "${PREVIEW_COLS[*]}")

# 7. Construir representacion del comando para mostrar en el output
CMD=$(construir_cmd)

# 8. Imprimir cabecera del output
imprimir_cabecera "$CMD"

# 9. Procesar el CSV (resultado escrito en TMP_FILE)
procesar_csv

# 10. Leer los resultados desde el archivo temporal
leer_resultados

# 11. Imprimir tabla y resultado final
imprimir_resultados
}
# ─── Punto de entrada ─────────────────────────────────────────────────────────
# Detectar --test/-t antes de entrar a main para no mezclar flujos
if [[ "$1" == "-t" || "$1" == "--test" ]]; then
    ejecutar_tests
    exit 0
fi
 
main "$@"
