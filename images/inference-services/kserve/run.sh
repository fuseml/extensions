#!/bin/sh

set -e
set -u
set -o pipefail

$FUSEML_VERBOSE && set -

. /opt/fuseml/scripts/helpers.sh

# load org and project from repository if exists,
# if not, set them as a random string
if [ -e ".fuseml/_project" ]; then
    export ORG=$(cat .fuseml/_org)
    export PROJECT=$(cat .fuseml/_project)
else
    export ORG=$(tr -dc a-z0-9 </dev/urandom | head -c 6 ; echo '')
    export PROJECT=$(tr -dc a-z0-9 </dev/urandom | head -c 6 ; echo '')
fi

export APP_NAME="${ORG}-${PROJECT}-${FUSEML_ENV_WORKFLOW_NAME}"
[ -n "$FUSEML_APP_NAME" ] && export APP_NAME=$FUSEML_APP_NAME

export S3_ENDPOINT=${MLFLOW_S3_ENDPOINT_URL/*:\/\//}
export PREDICTOR=${FUSEML_PREDICTOR}
export RUNTIME_VERSION=${FUSEML_RUNTIME_VERSION}

mc alias set minio ${MLFLOW_S3_ENDPOINT_URL} ${AWS_ACCESS_KEY_ID} ${AWS_SECRET_ACCESS_KEY}
model_bucket="minio${FUSEML_MODEL//s3:\//}"

if [ "${PREDICTOR}" = "auto" ]; then
    if ! mc stat "${model_bucket}"/MLmodel &> /dev/null ; then
        echo "No MLmodel found, cannot auto detect predictor"
        exit 1
    fi

    PREDICTOR=$(mc cat "${model_bucket}"/MLmodel | awk -F '.' '/loader_module:/ {print $2}')
    if [[ "${PREDICTOR}" =~ "^(onnx|keras)$" ]]; then
        PREDICTOR="triton"
    fi
fi

case $PREDICTOR in
    # kserve expects the tensorflow model to be under a numbered directory,
    # however mlflow saves the model under 'tfmodel' or 'data/model', so if there is no directory
    # named '1', create it and copy the tensorflow model to it.
    tensorflow)
        if ! mc stat "${model_bucket}"/1 &> /dev/null ; then
            mlmodel=$(mc cat "${model_bucket}"/MLmodel)
            flavor="$(echo "${mlmodel}" | grep -E -o '^\s{2}([a-z].*[a-z])' | grep -v python_function | tr -d ' ')"
            case ${flavor} in
                tensorflow)
                    mc cp -r "${model_bucket}"/tfmodel/ "${model_bucket}"/1
                    ;;
                keras)
                    mc cp -r "${model_bucket}"/data/model/ "${model_bucket}"/1
                    ;;
                *)
                    echo "Unsupported: ${flavor}"
                    echo "ERROR: Only Tensorflow/Keras (SavedModel) formats are supported by the tensorflow predictor"
                    exit 1
                    ;;
            esac
        fi
        if [ -z "${RUNTIME_VERSION}" ]; then
            export RUNTIME_VERSION=$(mc cat "${model_bucket}"/requirements.txt | awk -F '=' '/tensorflow/ {print $3; exit}')
        fi
        ;;
    # kserve expects the sklearn model file as model.joblib however mlflow
    # saves the model as model.pkl, so if there is no model.joblib, create a
    # copy named model.joblib from model.pkl
    sklearn)
        if ! mc ls "${model_bucket}" | grep -q "model.joblib"; then
            mc cp "${model_bucket}"/model.pkl "${model_bucket}"/model.joblib
        fi
        export PROTOCOL_VERSION="v2"
        ;;
    triton)
        # triton supports multiple serving backends, each has its own directory
        # structure (see: https://github.com/triton-inference-server/server/blob/main/docs/model_repository.md).
        export PROTOCOL_VERSION="v2"
        if [ -z "${RUNTIME_VERSION}" ]; then
            export RUNTIME_VERSION="21.10-py3"
        fi
        export ARGS="[--strict-model-config=false]"
        export FUSEML_MODEL="${FUSEML_MODEL}/triton"
        if ! mc stat "${model_bucket}"/triton &> /dev/null ; then
            mlmodel=$(mc cat "${model_bucket}"/MLmodel)
            flavor="$(echo "${mlmodel}" | grep -E -o '^\s{2}([a-z].*[a-z])' | grep -v python_function | tr -d ' ')"
            case ${flavor} in
                tensorflow)
                    mc cp -r "${model_bucket}"/tfmodel/ "${model_bucket}"/triton/"${APP_NAME}"/1/model.savedmodel
                    ;;
                keras)
                    mc cp -r "${model_bucket}"/data/model/ "${model_bucket}"/triton/"${APP_NAME}"/1/model.savedmodel
                    ;;
                onnx)
                    model_file="$(echo "${mlmodel}" | awk '/data:/ { print $2; exit }')"
                    mc cp -r "${model_bucket}"/"${model_file}" "${model_bucket}"/triton/"${APP_NAME}"/1/
                    ;;
                *)
                    echo "Unsupported: ${flavor}"
                    echo "ERROR: Only Tensorflow/Keras (SavedModel) and ONNX formats are supported"
                    exit 1
                    ;;
            esac
        fi
esac

new_ifs=true
if kubectl get inferenceservice/"${APP_NAME}" > /dev/null 2>&1; then
    new_ifs=false
fi

cat << EOF > /opt/kserve/templates/values.yaml
#@data/values
---
ifs:
  namespace: ${FUSEML_ENV_WORKFLOW_NAMESPACE}
  codeset: ${PROJECT}
  project: ${ORG}
  workflow: ${FUSEML_ENV_WORKFLOW_NAME}
  appName: ${FUSEML_APP_NAME}
  predictor:
    type: ${PREDICTOR}
    runtimeVersion: ${RUNTIME_VERSION}
    resources: 
      limits: ${FUSEML_RESOURCES_LIMITS}
  model:
    endpoint: ${S3_ENDPOINT}
    storageUri: ${FUSEML_MODEL}
    secretData: 
      AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}
      AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY}
EOF

$FUSEML_VERBOSE && cat /opt/kserve/templates/values.yaml
$FUSEML_VERBOSE && echo && ytt -f /opt/kserve/templates/

ytt -f /opt/kserve/templates/ | kubectl apply -f -

# if the inference service already exists, wait for its status to be updated
# with the new deployment (eventually it will transition to not Ready as it is
# waiting for the new deployment to be ready)
if [ "${new_ifs}" = false ] ; then
    kubectl wait --for=condition=Ready=false --timeout=30s inferenceservice/"${APP_NAME}" || true
fi

kubectl wait --for=condition=Ready --timeout=600s inferenceservice/"${APP_NAME}"

internal_url=$(kubectl get inferenceservice/"${APP_NAME}" -o jsonpath='{.status.address.url}')
prediction_url="$(kubectl get inferenceservice/"${APP_NAME}" -o jsonpath='{.status.url}')/${internal_url#*svc.cluster.local/}"
echo "${prediction_url}" > "/tekton/results/${TASK_RESULT}"

# Now, register the new application within fuseml; use kubectl only to format the output correctly
ytt -f /opt/kserve/templates/ | kubectl apply -f - --dry-run=client -o json | register_fuseml_app \
  --name "${APP_NAME}" \
  --desc "KServe service deployed for ${FUSEML_MODEL}" \
  --url "${prediction_url}" \
  --type predictor