#!/bin/sh

set -o pipefail

# generates a checksum based on the contents of a conda.yaml file
get_tag() {
    file=${1:-"conda.yaml"}
    dep_provider=""

    while IFS= read -r line; do
        name=$(echo ${line} | sed 's/ *- //g')
        case $line in
            '  - '*':')
                dep_provider=$(printf '%s' "${name}" | tr -d :)
            ;;
            '  - '*)
                if [ -z "${dependencies}" ]; then
                    dependencies=${name}
                else
                    dependencies=${dependencies}'\n'${name}
                fi
            ;;
            '    - '*)
                dependencies=${dependencies}'\n'${dep_provider}'.'${name}
            ;;
        esac
    done <"${file}"

    # insert the date to allow new container image versions to invalidate previously built builder containers
    printf "$(cat /build-timestamp.txt)$dependencies" | sort | cksum | cut -f 1 -d ' '
}

conda_file="conda.yaml"

if [ ! -f "${conda_file}" ]; then
    echo "${conda_file} not found in $(pwd)"
    exit 1
fi

registry=${FUSEML_REGISTRY:-"registry.fuseml-registry"}
repository=${FUSEML_REPOSITORY:-"mlflow/trainer"}
tag=$(get_tag)

# destination is the task output, when using the internal FuseML registry we need to reference the repository
# using the localhost address (see https://github.com/fuseml/fuseml/issues/65).
destination="${FUSEML_REGISTRY:-127.0.0.1:30500}/${repository}:${tag}"

if docker-ls tags ${repository} -r http://${registry} -j | jq -re ".tags | index(\"${tag}\")" &>/dev/null; then
    echo "${repository}:${tag} already exists, not building"
else
    echo "${repository}:${tag} not found in ${registry}, building..."
    mkdir -p .fuseml
    cp -r ${MLFLOW_DOCKERFILE}/* .fuseml/

    /kaniko/executor --insecure --dockerfile=.fuseml/Dockerfile  --context=./ --destination=${registry}/${repository}:${tag}
fi

printf ${destination} > /tekton/results/${TASK_RESULT}
