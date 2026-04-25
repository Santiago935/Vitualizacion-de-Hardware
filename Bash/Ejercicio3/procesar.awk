BEGIN {
    FS = "|" #le indico que la informacion que va a recibir esta separada por |
}

{
    clave = $1 "|" $2 #armo una clave unica de nombre+tamaño

    cantidad[clave]++  #contador de claves, va a figurar la cantidad de veces que aparece
    nombre[clave] = $1 #guardo el nombre del archivo

    directorios[clave] = directorios[clave] $3 "\n" #acumula todos los directorios donde aparece ese archivo repetido
}

END {
    encontrados = 0

    for (clave in cantidad) {
        if (cantidad[clave] > 1) {
            encontrados = 1

            print "archivo: " nombre[clave]

            cantDirectorios = split(directorios[clave], dirs, "\n") #toma un string y lo divido en partes, guardándolas en un array

            for (i = 1; i <= cantDirectorios; i++) {
                if (dirs[i] != "") {
                    print "directorio: " dirs[i]
                }
            }

            print ""
        }
    }

    if (encontrados == 0) {
        print "No se encontraron archivos duplicados."
    }
}