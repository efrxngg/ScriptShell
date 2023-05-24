#!/bin/bash

# Autor: efrxngg
# Descripción:
# Script para automatizar el proceso de cambio de versión en los archivos del proyecto
# y manejar diferentes ambientes a través de una interfaz de línea de comandos (CLI).
# Se basa en la convención SemVer, que consta de tres partes: major (Mayor), minor (Menor) y patch (Parche).
# Cada parte tiene un propósito específico y reglas para su modificación (Semantic Versioning).
# Además, permite el cambio en los archivos de configuración para el cambio de entorno: prod (Producción) e inc (Incubadora).
#
# [Requisitos]
# 1.- Definir las variables en el apartado de: # Variables del script [Modificable], ya sea para producción o incubadora.
#  Modifique únicamente las propiedades de las siguientes variables según corresponda.
#  Entiéndase por "propiedad" el valor que está después del signo igual (=) dentro de las comillas dobles (""). Por ejemplo: atributo="propiedad".
#  (EJEMPLO)
# - semver.sh
#   - name_project_production = "claro-service-waiver" -> Aquí se define el nombre del proyecto de OpenShift.
#   - route_production = "edx-renuncia-webbff.openshift-apps.conecel.com" -> Aquí se define la ruta que el route.yaml va a utilizar.
#   - number_replicas_prod = 2 -> Aquí se define la cantidad de réplicas a utilizar en el dc.yaml.
#
# 2.- Marcar las siguientes etiquetas con un comentario identificador
# - pom.xml:
#   - project/version: (EJEMPLO)
#     </version> <!-- idVersionProject -->
#
#   - project/artifactId: (EJEMPLO)
#     </artifactId> <!-- idArtifactProject -->
#
#   - project/properties/openshiftProjectName: (EJEMPLO)
#     </openshiftProjectName> <!-- idNameOpenShiftProjectSelected -->
#
# - dc.yaml:
#   - spec.replicas: (EJEMPLO)
#     replicas: 2 #idNumbReplicasSelected
#
#   - spec.template.spec.containers.image: (EJEMPLO)
#     image: docker-registry.default.svc:5000/claro-service-waiver/edx-renuncia-webbff:1.3.3 #idImageSelected
#
# - route.yml:
#   - spec.host: (EJEMPLO)
#     host: edx-renuncia-webbff.openshift-apps.conecel.com #idHostSelected
#
# [Uso]
# Para utilizar el script, debe ubicarlo en la ruta base de su proyecto.
# Ejecute el script en una shell bash proporcionando las opciones y argumentos correspondientes.
#
# Opciones disponibles:
# -t <tipo>:
#    Especifica el tipo de cambio de versión a realizar en el proyecto y sus configuraciones, que puede ser:
#    - major (Mayor): Modifica X.0.0
#      - Para cambios incompatibles,
#      - eliminación de funcionalidades existentes,
#      - cambios en la estructura de la base de datos que afectan la compatibilidad hacia atrás,
#      - modificaciones significativas en la forma en que se utilizan o interactúan los componentes principales.
#    - minor (Menor): Modifica 0.X.0
#      - Para nuevas funcionalidades,
#      - mejoras en las funcionalidades existentes sin romper la compatibilidad,
#      - expansión de la API existente de forma compatible.
#    - patch (Parche): Modifica 0.0.X
#      - Para solución de errores conocidos,
#      - parcheo de vulnerabilidades de seguridad,
#      - pequeñas mejoras de rendimiento.
#
# -e <entorno>: Especifica el ambiente al cual se desea cambiar.
#    - prod: cambia las rutas, el deployment config y el pom para el pase a producción.
#    - inc: cambia las rutas, el deployment config y el pom para el pase a incubadora.
#
# Ejemplo de uso:
# ./script.sh -t patch -e prod
#
# [Notas]
# - Las banderas se pueden colocar independientemente una de la otra:
#   - ./script.sh -t patch
#   - ./script.sh -e prod
# - En caso de que sea necesario, se puede modificar la #ruta del proyecto
#   para indicar la ruta base del proyecto en el que se desea realizar la modificación.

# [Ref]
# Semantic Versioning. Recuperado de https://semver.org/

# Variables del script [Modificable]
# [Produccion]
name_project_production="claro-service-waiver"
route_production="edx-renuncia-webbff.openshift-apps.conecel.com"
number_replicas_prod=2
# [Incubadora]
name_project_incubadora="claro-edx-incubadora"
route_incubadora="incubadora-edx-renuncia-webbff.openshift-apps.conecel.com"
number_replicas_inc=1

# Constantes del Script [UnModifiable]
path="." #ruta del proyecto
path_info="$path/pom.xml"   #ruta del pom

idVersion="<!-- idVersionProject -->"                     #identificador de la version del proyecto
idArtifact="<!-- idArtifactProject -->"                   #identificador de artifact del proyecto
idOpenShiftName="<!-- idNameOpenShiftProjectSelected -->" #identificador de nombre del proyecto en openshift
idNumbReplicas="#idNumbReplicasSelected"                  #identicador del numero de replicas seleccionadas
idImage="#idImageSelected"                                #identificador de numero de imagenes seleccionadas
idHost="#idHostSelected"                                  #identificador del host seleccionado

# Variables de utilidad
project_artifact="" #artefacto del proyecto
current_version=""  #version actual del proyecto
new_version=""      #version nueva

type=""        #tipo de cambio de version: major, minor 0 patch
environment="" #tipo de entorno: prod, inc

# Version Functions
getPomInformation() {
    local patternVersion="<version>([^<]+)<\/version> $idVersion"         #Para que funcione se le debe añadir ese comentario
    local patternArtifact="<artifactId>([^<]+)<\/artifactId> $idArtifact" #Para que funcione se le debe añadir ese comentario
    local contador=0
    while IFS= read -r linea; do
        if [ $contador -eq 2 ]; then
            break
        fi

        linea=$(echo "$linea" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        if [[ "$linea" =~ $patternVersion ]]; then
            current_version="${BASH_REMATCH[1]}"
            ((contador++))
        fi

        if [[ "$linea" =~ $patternArtifact ]]; then
            project_artifact="${BASH_REMATCH[1]}"
            ((contador++))
        fi
    done <"$path_info"
}

modifySemver() {
    local type="$1"

    # Verificar si el argumento type es válido
    if [[ "$type" != "major" && "$type" != "minor" && "$type" != "patch" ]]; then
        echo "Error: Tipo de versión inválido. Debe ser 'major', 'minor' o 'patch'."
        exit 1
    fi

    # Extraer las partes del número de versión
    local prefix=""
    local major=""
    local minor=""
    local patch=""
    local sufix=""

    if [[ "$current_version" =~ ([^0-9]*)([0-9]+)\.([0-9]+)\.([0-9]+)([^0-9]*) ]]; then
        prefix="${BASH_REMATCH[1]}"
        major="${BASH_REMATCH[2]}"
        minor="${BASH_REMATCH[3]}"
        patch="${BASH_REMATCH[4]}"
        sufix="${BASH_REMATCH[5]}"
    fi

    # Incrementar la parte correspondiente según el tipo especificado
    case "$type" in
    "major")
        ((major++))
        minor=0
        patch=0
        ;;
    "minor")
        ((minor++))
        patch=0
        ;;
    "patch")
        ((patch++))
        ;;
    esac

    # Construir la nueva versión modificada
    new_version="$prefix$major.$minor.$patch$sufix"
    echo "Version<old: $current_version | new: $new_version>"
}

upgradeVersionForProject() {
    modifySemver "$type"
    local oldVersion="<version>$current_version<\/version> $idVersion"
    local nowVersion="<version>$new_version<\/version> $idVersion"
    sed -i "s/$oldVersion/$nowVersion/g" "$path_info"
}

upgradeAllVersionForDeploymentConfig() {
    # Buscamos y reemplazamos el artifact en los archivos de la ruta especificada
    local pathFile="$path/deploy"
    find "$pathFile" -type f -exec grep -l "$project_artifact-$current_version" {} + | xargs sed -i "s/$project_artifact-$current_version/$project_artifact-$new_version/g"
    find "$pathFile" -type f -exec grep -l "$project_artifact:$current_version" {} + | xargs sed -i "s/$project_artifact:$current_version/$project_artifact:$new_version/g"
    echo "Artifact<old: $project_artifact-$current_version | new: $project_artifact-$new_version>"
}

# Environment functions
changeRoute() {
    local route="$1"
    local pathFile="$path/deploy"
    local pattern="host: .* $idHost"
    find "$pathFile" -type f -exec grep -l "$pattern" {} + | xargs sed -i "s/$pattern/host: $route $idHost/g"
}

changeNumbReplicas() {
    local numbReplicas="$1"
    local pathFile="$path/deploy"
    local pattern="replicas: .* $idNumbReplicas"
    find "$pathFile" -type f -exec grep -l "$pattern" {} + | xargs sed -i "s/$pattern/replicas: $numbReplicas $idNumbReplicas/g"
}

changeImage() {
    local image="$1"
    local pathFile="$path/deploy"
    local pattern="image: \([^/]\+\)/.*/\([^/]\+\) $idImage"
    local replacement="image: \1/$image/\2 $idImage"
    find "$pathFile" -type f -exec grep -q "$pattern" {} \; -exec sed -i "s@$pattern@$replacement@g" {} +
}

changeNameOpenShift() {
    local name="$1"
    local pattern="<openshiftProjectName>.*<\/openshiftProjectName> $idOpenShiftName"
    local newOSN="<openshiftProjectName>$name<\/openshiftProjectName> $idOpenShiftName"
    sed -i "s/$pattern/$newOSN/g" "$path_info"
}

modifyEnvironment() {
    local env="$1"
    # Verificar si el argumento type es válido
    if [[ "$env" != "prod" && "$env" != "inc" ]]; then
        echo "Error: Tipo de entorno es inválido. Debe ser 'prod' o 'inc'."
        exit 1
    fi

    case "$env" in
    "prod")
        changeRoute "$route_production"
        changeNumbReplicas "$number_replicas_prod"
        changeImage "$name_project_production"
        changeNameOpenShift "$name_project_production"
        ;;
    "inc")
        changeRoute "$route_incubadora"
        changeNumbReplicas "$number_replicas_inc"
        changeImage "$name_project_incubadora"
        changeNameOpenShift "$name_project_incubadora"
        ;;
    esac
}

# Call Function
inputArgs() {
    while getopts "t:e:" opt; do
        case $opt in
        t)
            type=$OPTARG
            ;;
        e)
            environment=$OPTARG
            ;;
        \?)
            echo "Opción inválida: -$OPTARG" >&2
            exit 1
            ;;
        esac
    done
}

validateVariables() {
    # Variables de producción
    if [[ -z "$name_project_production" || -z "$route_production" || -z "$number_replicas_prod" ]]; then
        echo "Falta completar algunas variables de producción."
        exit 1
    fi

    # Variables de incubadora
    if [[ -z "$name_project_incubadora" || -z "$route_incubadora" || -z "$number_replicas_inc" ]]; then
        echo "Falta completar algunas variables de incubadora."
        exit 1
    fi
}

inputArgs "$@"

if [[ $type != "" ]]; then
    echo "Tipo cambio de version: $type"
    getPomInformation
    upgradeVersionForProject
    upgradeAllVersionForDeploymentConfig
fi

if [[ $environment != "" ]]; then
    echo "Tipo de cambio de entorno a: $environment"
    validateVariables
    modifyEnvironment "$environment"
fi
