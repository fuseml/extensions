#!/bin/bash

#
# FuseML ML model conversion workflow step that can be used to convert models
# and/or to move them between different model storage locations.
#
# Supported input model formats:
#
#   auto (default)
#   mlflow
#   tensorflow.saved_model
#   onnx
#
# Supported output model formats:
#   
#   onnx
#   openvino (default)
#
# Supported input model storage types:
#
#   local path
#   HTTP/HTTPs remote location
#   S3 storage
#   GCS storage
#
# Supported output model storage types:
#
#   local path
#   S3 storage
#   GCS storage
#
# This converter workflow step is implemented in 3 stages, some of which won't
# need to be executed, depending on the use-case:
#
# 1. if the input model is stored remotely (e.g. S3 or GCS), it is downloaded locally.
# This doesn't apply to local paths (e.g. models mounted from a codeset).
#
# 2. model conversion is performed locally. This doesn't apply if the input and output
# formats are one and the same.
#
# 3. if the output model path points to a remote location (e.g. S3 or GCS),
# the converted model is uploaded to that location.
#


set -ex
set -u
set -o pipefail

# unless explicitly set, use the same remote S3/GCS output credentials as the input
if [ -z "$OUTPUT_S3_ENDPOINT" ] && [ -z "$OUTPUT_AWS_ACCESS_KEY_ID" ] && [ -z "$OUTPUT_AWS_SECRET_ACCESS_KEY" ]; then
    OUTPUT_S3_ENDPOINT=$S3_ENDPOINT
    OUTPUT_AWS_ACCESS_KEY_ID=$AWS_ACCESS_KEY_ID
    OUTPUT_AWS_SECRET_ACCESS_KEY=$AWS_SECRET_ACCESS_KEY
fi

fuseml_workspace=/opt/fuseml/workspace
input_format=${FUSEML_INPUT_FORMAT}
input_model=${FUSEML_INPUT_MODEL}
output_model=${FUSEML_OUTPUT_MODEL}
output_format=${FUSEML_OUTPUT_FORMAT}

# use the same location as the input model, unless explicitly specified 
if [ -z "${output_model}" ]; then
    output_model="${input_model}"
fi

# default local path for input model
input_model_base_path="${fuseml_workspace}/input"
mkdir -p $input_model_base_path
# default local path for model output
output_model_base_path="${fuseml_workspace}/output"
mkdir -p $output_model_base_path


# --- Stage 1. ---- download model(s) locally

# local input model path
if [[ "${input_model}" =~ ^/.* ]]; then
    if [ ! -e "${input_model}" ]; then
        echo "Local path not found or not accessible: ${input_model}"
        exit 1
    fi
    echo "Using local model path: ${input_model}"

# download the model locally, if accessible through HTTP/S
elif [[ "${input_model}" =~ ^https?://.* ]]; then
    echo "Dowloading model from remote location: ${input_model} ..."
    wget --no-parent -r -P "${output_model_base_path}" "${input_model}"
    input_model=${input_model_base_path}/$(basename "${input_model}")

# download the model locally, if stored in an S3 bucket
elif [[ "${input_model}" = "s3://"* ]]; then
    echo "Dowloading model from S3 remote storage: ${input_model} ..."

    # default to AWS storage, unless the S3 endpoint is explicitly set to something else (e.g. minio)
    : "${S3_ENDPOINT:=https://s3.amazonaws.com}"

    mc alias set s3 "${S3_ENDPOINT}" "${AWS_ACCESS_KEY_ID}" "${AWS_SECRET_ACCESS_KEY}"
    model_bucket="s3${input_model//s3:\//}"
    mc cp -r "${model_bucket}" "${input_model_base_path}"
    input_model=${input_model_base_path}/$(basename "${input_model}")

# download the model locally, if stored in GCS bucket
elif [[ "${input_model}" = "gs://"* ]]; then
    echo "Dowloading model from GCS storage: ${input_model} ..."
    mc alias set gs https://storage.googleapis.com "${AWS_ACCESS_KEY_ID}" "${AWS_SECRET_ACCESS_KEY}"
    model_bucket="gs${input_model//gs:\//}"
    mc cp -r "${model_bucket}" "${input_model_base_path}"
    input_model=${input_model_base_path}/$(basename "${input_model}")
else
    echo "Unsupported input storage type: ${input_model}"
    exit 1
fi


# --- Stage 2. ---- convert model(s)

if [ "${input_format}" = "auto" ]; then
    # detect an MLFlow model
    if [ -f "${input_model}/MLmodel" ]; then
        input_format=mlflow
        echo "MLFlow model detected"
    else
        echo "No MLmodel file found at input model path. Cannot auto-detect model format"
        exit 1
    fi
fi

if [ "$input_format" = "mlflow" ]; then
    if [ ! -f "${input_model}/MLmodel" ]; then
        echo "No MLmodel file found at input model path"
        exit 1
    fi

    mlmodel=$(cat "${input_model}/MLmodel")
    input_format=$(echo "${mlmodel}" | yq e '.flavors.python_function.loader_module' -)
    echo "MLFlow model format detected: ${input_format}"

    case $input_format in
        mlflow.tensorflow)
            input_model="${input_model}/$(echo "${mlmodel}" | yq e '.flavors.tensorflow.saved_model_dir' -)"
            input_format=tensorflow.saved_model
            ;;
        mlflow.keras)
            input_model="${input_model}/$(echo "${mlmodel}" | yq e '.flavors.python_function.data' -)"
            save_format="$(echo "${mlmodel}" | yq e '.flavors.keras.save_format' -)"
            if [ "$save_format" = "tf" ]; then
                input_format=tensorflow.saved_model
                # the TF saved_model is under a 'model' subdir
                input_model="${input_model}/model"
            else
                # probably Keras H5 format
                input_format="keras.${save_format}"
            fi
            ;;
        mlflow.sklearn)
            input_model="${input_model}/$(echo "${mlmodel}" | yq e '.flavors.python_function.model_path' -)"
            input_format="sklearn.$(echo "${mlmodel}" | yq e '.flavors.sklearn.serialization_format' -)"
            ;;
        mlflow.onnx)
            input_model="${input_model}/$(echo "${mlmodel}" | yq e '.flavors.python_function.data' -)"
            input_format=onnx
            ;;
        *)
            echo "Conversion for MLFlow model format ${input_model} not supported yet."
            exit 1
            ;;
    esac
    echo "Model format detected: ${input_format}"
fi

output_model_path=$output_model_base_path

if [ "$output_format" = "$input_format" ]; then
    # no conversion requested, this is just a change of location/storage backend
    output_model_path=$input_model
elif [ "$output_format" = "openvino" ]; then
    case $input_format in
        tensorflow.saved_model)
            echo "Converting from TensorFlow saved_model to OpenVINO format"
            echo "Input saved_model model summary:"
            saved_model_cli show --all --dir "${input_model}" || true
            output_model_path="${output_model_path}/$(basename ${input_model})"
            deployment_tools/model_optimizer/mo_tf.py --saved_model_dir "${input_model}" --saved_model_tags serve --output_dir "${output_model_path}"
            ;;
        onnx)
            deployment_tools/model_optimizer/mo.py --input_model "${input_model}" --output_dir "${output_model_path}"
            ;;
        *)
            echo "Conversion from format '${input_format}' to OpenVINO format not supported yet."
            exit 1
            ;;
    esac
else
    echo "Conversion to format '${output_format}' not supported yet."
    exit 1
fi

# --- Stage 3. ---- upload model(s) remotely

# local input model path
if [[ "${output_model}" =~ ^/.* ]]; then
    cp -r "${output_model_path}" "${output_model}"

# upload the model remotely, if stored in an S3 bucket
elif [[ "${output_model}" = "s3://"* ]]; then
    echo "Uploading model to S3 remote storage: ${output_model} ..."
    mc alias set s3 "${OUTPUT_S3_ENDPOINT}" "${OUTPUT_AWS_ACCESS_KEY_ID}" "${OUTPUT_AWS_SECRET_ACCESS_KEY}"
    model_bucket="s3${output_model//s3:\//}"
    mc cp -r "${output_model_path}" "${model_bucket}"

# upload the model remotely, if stored in GCS
elif [[ "${output_model}" = "gs://"* ]]; then
    echo "Uploading model to GCS remote storage: ${output_model} ..."
    mc alias set gs https://storage.googleapis.com "${OUTPUT_AWS_ACCESS_KEY_ID}" "${OUTPUT_AWS_SECRET_ACCESS_KEY}"
    model_bucket="gs${output_model//gs:\//}"
    mc cp -r "${output_model_path}" "${model_bucket}"

else
    echo "Unsupported output storage type: ${output_model}"
    exit 1
fi

echo "${output_model}" > /tekton/results/${TASK_RESULT}
