#!/bin/bash

# Autor: efrxngg
# Descripción:
# Script para automatizar el proceso de cambio de versión en los archivos del proyecto
# y manejar diferentes escenarios de uso mediante la interfaz de línea de comandos (CLI).

# Variables del Script [No tocar]
path=""      #ruta del proyecto
path_info="" #ruta del pom

idVersion="idVersionProject"   #identificador de la version del proyecto
idArtifact="idArtifactProject" #identificacion de artifact del proyecto

current_version=""     #version actual
project_artifact=""    #artefacto del proyecto
new_version=""         #version nueva
pattern_line_change="" #patron de la linea del proyecto

type=""        #tipo de cambio de version: major, minor 0 patch
environment="" #tipo de entorno: prod, inc

# Functions
getPomInformation() {
    path="$1"
    path_info="$path/pom.xml"
    local patternVersion="<version>([^<]+)<\/version> <!-- $idVersion -->"         #Para que funcione se le debe añadir ese comentario
    local patternArtifact="<artifactId>([^<]+)<\/artifactId> <!-- $idArtifact -->" #Para que funcione se le debe añadir ese comentario
    contador=0
    while IFS= read -r linea; do
        if [ $contador -eq 2 ]; then
            break
        fi

        pattern_line_change="$linea"
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
        return 1
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
    local escaped_pattern_line_change=$(sed 's/[[\.*^$/]/\\&/g' <<<"$pattern_line_change")
    local escaped_new_version=$(sed 's/[[\.*^$/]/\\&/g' <<<"$new_version")
    sed -i "s/$escaped_pattern_line_change/    <version>$escaped_new_version<\/version> <!-- $idVersion -->/g" "$path_info"
}

updateAllArtifactForProyect() {
    # Buscamos y reemplazamos el artifact en los archivos de la ruta especificada
    local pathFile="$path/deploy"
    if [[ $new_version != "" ]]; then
        find "$pathFile" -type f -exec grep -l "$project_artifact-$current_version" {} + | xargs sed -i "s/$project_artifact-$current_version/$project_artifact-$new_version/g"
        find "$pathFile" -type f -exec grep -l "$project_artifact:$current_version" {} + | xargs sed -i "s/$project_artifact:$current_version/$project_artifact:$new_version/g"
        echo "Artifact<old: $project_artifact-$current_version | new: $project_artifact-$new_version>"
    fi
}

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

# Call
inputArgs "$@"

if [[ $type != "" ]]; then
    echo "Tipo cambio de version: $type"
    getPomInformation "./retentionprocesses"
    modifySemver "$type"
    changeVersion
    updateAllArtifactForProyect
fi
