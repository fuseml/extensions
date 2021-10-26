#!/bin/sh

set -e
set -o pipefail
set -x

BUILDARGS=""

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
    printf "$(cat /build-timestamp.txt)$dependencies$BUILDARGS" | sort | cksum | cut -f 1 -d ' '
}


if [ ! -f "conda.yaml" ]; then
    if [ ! -f "requirements.txt" ]; then
        echo "Neither conda.yaml not requirements.txt found in $(pwd)"
        exit 1
    fi
    # prepare conda.yaml based on existing requirements.txt
    cat > conda.yaml << EOF
name: mlflow
dependencies:
  - pip
  - pip:
$(cat requirements.txt | sed 's/^/    - /')
EOF

fi

registry=${FUSEML_REGISTRY:-"registry.fuseml-registry"}
repository=${FUSEML_REPOSITORY:-"mlflow/trainer"}

if [ -n "${FUSEML_MINICONDA_VERSION}" ]; then
    BUILDARGS="$BUILDARGS --build-arg MINICONDA_VERSION=$FUSEML_MINICONDA_VERSION"
fi
if [ -n "${FUSEML_INTEL_BASE_IMAGE}" ]; then
    BUILDARGS="$BUILDARGS --build-arg INTEL_BASE_IMAGE=$FUSEML_INTEL_BASE_IMAGE"
fi
if [ -n "${FUSEML_INTEL_OPTIMIZED}" ]; then
    BUILDARGS="$BUILDARGS --build-arg BASE=intel"
fi

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

    /kaniko/executor --insecure --dockerfile=.fuseml/Dockerfile  --context=./ --destination=${registry}/${repository}:${tag} $BUILDARGS
fi

printf ${destination} > /tekton/results/${TASK_RESULT}
