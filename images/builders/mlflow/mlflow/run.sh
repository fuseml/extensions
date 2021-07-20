#!/bin/bash

set -e
set -u
set -o pipefail

set_exp_name=""
if [ -e .fuseml/_project ]; then
    set_exp_name="--experiment-name $(cat .fuseml/_org).$(cat .fuseml/_project)"
fi

mlflow run --no-conda ${set_exp_name} . 2>&1 | tee train.log

run_id=$(grep -oEm1 '[a-f0-9]{32}' train.log)
model_uri="$(mlflow runs describe --run-id ${run_id} | grep -oEm1 's3.*artifacts')/model"

if [ -n "$TASK_RESULT" ]; then
    printf "${model_uri}" > /tekton/results/${TASK_RESULT}
fi

