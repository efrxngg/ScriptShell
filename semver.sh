#!/bin/bash

# Variables
path="" #ruta del proyecto

#Identificadores
idVersion="idVersionProject"
idArtifact="idArtifactProject"

current_version="" #version actual
project_artifact=""
new_version=""       #version nueva
patternLineChange="" #patron de la linea del proyecto
pathInfo=""
# Functions

getInformation() {
    path="$1"
    pathInfo="$path/pom.xml"
    local patternVersion="<version>([^<]+)<\/version> <!-- $idVersion -->"         #Para que funcione se le debe añadir ese comentario
    local patternArtifact="<artifactId>([^<]+)<\/artifactId> <!-- $idArtifact -->" #Para que funcione se le debe añadir ese comentario
    contador=0
    while IFS= read -r linea; do
        if [ $contador -eq 2 ]; then
            echo "El contador es igual a 2. Deteniendo el bucle."
            break
        fi

        patternLineChange="$linea"
        linea=$(echo "$linea" | sed -e 's/^[[:space:]]*//' -e 's/[[:space:]]*$//')
        if [[ "$linea" =~ $patternVersion ]]; then
            current_version="${BASH_REMATCH[1]}"
            ((contador++))
        fi
        if [[ "$linea" =~ $patternArtifact ]]; then
            project_artifact="${BASH_REMATCH[1]}"
            ((contador++))
        fi
    done <"$pathInfo"
}

modify_semver() {
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
    local escaped_patternLineChange=$(sed 's/[[\.*^$/]/\\&/g' <<<"$patternLineChange")
    local escaped_new_version=$(sed 's/[[\.*^$/]/\\&/g' <<<"$new_version")
    sed -i "s/$escaped_patternLineChange/    <version>$escaped_new_version<\/version> <!-- $idVersion -->/g" "$pathInfo"
}

updateAllArtifactForProyect() {
    local old_artifact="$1"
    local new_artifact="$2"

    # Buscamos y reemplazamos el artifact en los archivos de la ruta especificada
    local pathFile="$path/deploy/docker/Dockerfile"
    find "$pathFile" -type f -exec sed -i "s/$old_artifact/$new_artifact/g" {} +
}

# Uso
getInformation "./retentionprocesses"
echo "Version old: $current_version"

modify_semver "patch"
echo "Version new: $new_version"

changeVersion
echo "Artifact old: $project_artifact-$current_version"
echo "Artifact new: $project_artifact-$new_version"

updateAllArtifactForProyect "$project_artifact-$current_version" "$project_artifact-$new_version"

