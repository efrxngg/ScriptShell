#!/bin/bash

# Autor: efrxngg
# Descripción:
# Script para automatizar el proceso de cambio de versión en los archivos del proyecto
# y manejar diferentes escenarios de uso mediante la interfaz de línea de comandos (CLI).

# Variables del Script [No tocar]
path="" #ruta del proyecto

#Identificadores
idVersion="idVersionProject"
idArtifact="idArtifactProject"

current_version="" #version actual
project_artifact="" #artefacto del proyecto
new_version=""       #version nueva
pattern_line_change="" #patron de la linea del proyecto
path_info=""
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
}

changeVersion() {
    local escaped_pattern_line_change=$(sed 's/[[\.*^$/]/\\&/g' <<<"$pattern_line_change")
    local escaped_new_version=$(sed 's/[[\.*^$/]/\\&/g' <<<"$new_version")
    sed -i "s/$escaped_pattern_line_change/    <version>$escaped_new_version<\/version> <!-- $idVersion -->/g" "$path_info"
}

updateAllArtifactForProyect() {
    # Buscamos y reemplazamos el artifact en los archivos de la ruta especificada
    local pathFile="$path/deploy"
    find "$pathFile" -type f -exec grep -l "$project_artifact-$current_version" {} + | xargs sed -i "s/$project_artifact-$current_version/$project_artifact-$new_version/g"
    find "$pathFile" -type f -exec grep -l "$project_artifact:$current_version" {} + | xargs sed -i "s/$project_artifact:$current_version/$project_artifact:$new_version/g"
}

# Uso
getPomInformation "./retentionprocesses"
echo "Version old: $current_version"

modifySemver "patch"
echo "Version new: $new_version"

changeVersion
echo "Artifact old: $project_artifact-$current_version"
echo "Artifact new: $project_artifact-$new_version"

updateAllArtifactForProyect 

