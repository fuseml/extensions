#!/bin/bash

set -ex
set -u
set -o pipefail

mc alias set model-store "${S3_ENDPOINT}" "${AWS_ACCESS_KEY_ID}" "${AWS_SECRET_ACCESS_KEY}"
model_bucket="model-store${FUSEML_MODEL//s3:\//}"

FUSEML_WORKSPACE=/opt/fuseml/workspace
INPUT_FORMAT=${FUSEML_MODEL_FORMAT}
INPUT_SHAPE=${FUSEML_INPUT_SHAPE}
model_path=""

if [ "${INPUT_FORMAT}" = "auto" ]; then
    # detect an MLFlow model
    if mc stat "${model_bucket}/MLmodel" &> /dev/null ; then
        mlmodel="$(mc cat ${model_bucket}/MLmodel)"
        mlformat=$(echo "${mlmodel}" | yq e '.flavors.python_function.loader_module' -)
        echo "MLFlow model format detected: ${mlformat}"
        case $mlformat in
            mlflow.tensorflow)
                model_path="$(echo "${mlmodel}" | yq e '.flavors.tensorflow.saved_model_dir' -)"
                INPUT_FORMAT=tensorflow.saved_model
                ;;
            mlflow.sklearn)
                model_path="$(echo "${mlmodel}" | yq e '.flavors.python_function.model_path' -)"
                INPUT_FORMAT="sklearn.$(echo "${mlmodel}" | yq e '.flavors.sklearn.serialization_format' -)"
                ;;
            mlflow.onnx)
                model_path="$(echo ${mlmodel} | yq e '.flavors.python_function.data' -)"
                INPUT_FORMAT=onnx
                ;;
            *)
                echo "Conversion for MLFlow model format ${mlformat} not supported yet."
                exit 1
                ;;
        esac
        echo "Model format detected: ${INPUT_FORMAT}"
    else
        echo "No MLmodel file found at input model path. Cannot auto-detect model format"
        exit 1
    fi
fi

extra_args=""
if [ -n "${INPUT_SHAPE}" ]; then
    extra_args="--input_shape ${INPUT_SHAPE}"
fi

case $INPUT_FORMAT in
    tensorflow.saved_model)
        mc cp -r "${model_bucket}/${model_path}" "${FUSEML_WORKSPACE}"
        deployment_tools/model_optimizer/mo_tf.py --saved_model_dir "${FUSEML_WORKSPACE}/${model_path}" --saved_model_tags serve --output_dir "${FUSEML_WORKSPACE}/ovms" ${extra_args}
        mc cp -r "${FUSEML_WORKSPACE}/ovms" "${model_bucket}"
        ;;
    onnx)
        mc cp -r "${model_bucket}/${model_path}" "${FUSEML_WORKSPACE}"
        deployment_tools/model_optimizer/mo.py --input_model "${FUSEML_WORKSPACE}/${model_path}" --output_dir "${FUSEML_WORKSPACE}/ovms" ${extra_args}
        mc cp -r "${FUSEML_WORKSPACE}/ovms" "${model_bucket}"
        ;;
    *)
        echo "Conversion for MLmodel format ${INPUT_FORMAT} not supported yet."
        exit 1
        ;;
esac

echo "${FUSEML_MODEL}/ovms" > /tekton/results/${TASK_RESULT}
