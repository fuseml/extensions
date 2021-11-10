#!/bin/bash

set -e
set -u
set -o pipefail

$FUSEML_VERBOSE && set -x

if [ -z "$FUSEML_MLFLOW_EXPERIMENT" ] && [ -e .fuseml/_project ]; then
    FUSEML_MLFLOW_EXPERIMENT="$(cat .fuseml/_org).$(cat .fuseml/_project)"
fi

exec mlflow_run --workdir . \
                --entrypoint ${FUSEML_MLFLOW_ENTRYPOINT} \
                --entrypoint_args ${FUSEML_MLFLOW_ENTRYPOINT_ARGS} \
                --experiment ${FUSEML_MLFLOW_EXPERIMENT} \
                --artifact_subpath ${FUSEML_MLFLOW_ARTIFACT_PATH} \
                --save_result_to_file /tekton/results/${TASK_RESULT}
