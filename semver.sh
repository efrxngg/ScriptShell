#!/bin/bash

# Autor: efrxngg
# Descripción:
# Script para automatizar el proceso de cambio de versión en los archivos del proyecto
# y manejar diferentes escenarios de uso mediante la interfaz de línea de comandos (CLI).

# [Requisitos]
# Marcar las etiquetas artifactId, version, openshiftProjectName con un comentario identificador
# </artifactId> <!-- idArtifactProject -->
# </version> <!-- idVersionProject -->
# </openshiftProjectName> <!-- idOpenShiftName -->

# Variables del script [Modificable]
# [Produccion]
name_project_production="claro-service-waiver"
route_producion="edx-renuncia-webbff.openshift-apps.conecel.com"
# [Incubadora]
name_project_incubadora="claro-edx-incubadora"
route_incubadora="incubadora-edx-renuncia-webbff.openshift-apps.conecel.com"

# Variables del Script [UnModifiable]
path=""      #ruta del proyecto
path_info="" #ruta del pom

idVersion="<!-- idVersionProject -->"             #identificador de la version del proyecto
idArtifact="<!-- idArtifactProject -->"           #identificacion de artifact del proyecto
idOpenShiftName="<!-- idOpenShiftNameProject -->" #identificacion de artifact del proyecto

project_artifact="" #artefacto del proyecto
current_version=""  #version actual del proyecto
new_version=""      #version nueva

type=""        #tipo de cambio de version: major, minor 0 patch
environment="" #tipo de entorno: prod, inc

# Functions
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

getPomInformation() {
    path="$1"
    path_info="$path/pom.xml"
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
    local major=$(echo "$current_version" | cut -d '.' -f 1)
    local minor=$(echo "$current_version" | cut -d '.' -f 2)
    local patch=$(echo "$current_version" | cut -d '.' -f 3)

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
    new_version="$major.$minor.$patch"
    echo "Version<old: $current_version | new: $new_version>"
}

changeVersion() {
    local oldVersion="<version>$current_version<\/version> $idVersion"
    local nowVersion="<version>$new_version<\/version> $idVersion"
    sed -i "s/$oldVersion/$nowVersion/g" "$path_info"
}

updateAllArtifactForProyect() {
    # Buscamos y reemplazamos el artifact en los archivos de la ruta especificada
    local pathFile="$path/deploy"
    find "$pathFile" -type f -exec grep -l "$project_artifact-$current_version" {} + | xargs sed -i "s/$project_artifact-$current_version/$project_artifact-$new_version/g"
    find "$pathFile" -type f -exec grep -l "$project_artifact:$current_version" {} + | xargs sed -i "s/$project_artifact:$current_version/$project_artifact:$new_version/g"
    echo "Artifact<old: $project_artifact-$current_version | new: $project_artifact-$new_version>"
}

# Call
inputArgs "$@"

if [[ $type != "" ]]; then
    echo "Tipo cambio de version: $type"
    getPomInformation "./retentionprocesses"
    modifySemver "$type"
    changeVersion
    updateAllArtifactForProyect
fi
