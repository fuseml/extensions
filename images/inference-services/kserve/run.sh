#!/bin/sh

set -e
set -u
set -o pipefail

$FUSEML_VERBOSE && set -x

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

mc alias set minio ${MLFLOW_S3_ENDPOINT_URL} ${AWS_ACCESS_KEY_ID} ${AWS_SECRET_ACCESS_KEY}
model_bucket="minio${FUSEML_MODEL//s3:\//}"

export PROTOCOL_VERSION="v1"
export PREDICTOR=${FUSEML_PREDICTOR}
export RUNTIME_VERSION=${FUSEML_RUNTIME_VERSION}
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
        prediction_url_path="${APP_NAME}:predict"
        ;;
    # kserve expects the sklearn model file as model.joblib however mlflow
    # saves the model as model.pkl, so if there is no model.joblib, create a
    # copy named model.joblib from model.pkl
    sklearn)
        if ! mc ls "${model_bucket}" | grep -q "model.joblib"; then
            mc cp "${model_bucket}"/model.pkl "${model_bucket}"/model.joblib
        fi
        export PROTOCOL_VERSION="v2"
        prediction_url_path="${APP_NAME}/infer"
        ;;
    triton)
        # triton supports multiple serving backends, each has its own directory
        # structure (see: https://github.com/triton-inference-server/server/blob/main/docs/model_repository.md).
        export PROTOCOL_VERSION="v2"
        if [ -z "${RUNTIME_VERSION}" ]; then
            export RUNTIME_VERSION="21.09-py3"
        fi
        export ARGS="[--strict-model-config=false]"
        export FUSEML_MODEL="${FUSEML_MODEL}/triton"
        prediction_url_path="${APP_NAME}/infer"
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

RESOURCES_LIMITS="{cpu: 1000m, memory: 2Gi}"
# set inference service container resources if specified
if [ -n "${FUSEML_RESOURCES_LIMITS}" ]; then
    RESOURCES_LIMITS="${FUSEML_RESOURCES_LIMITS}"
fi
export RESOURCES_LIMITS

new_ifs=true
if kubectl get inferenceservice/${APP_NAME} > /dev/null 2>&1; then
    new_ifs=false
fi

envsubst < /root/template.sh > /tmp/kube-resources.yaml
$FUSEML_VERBOSE && cat /tmp/kube-resources.yaml
kubectl apply -f /tmp/kube-resources.yaml

# if the inference service already exists, wait for its status to be updated
# with the new deployment (eventually it will transition to not Ready as it is
# waiting for the new deployment to be ready)
if [ "${new_ifs}" = false ] ; then
    kubectl wait --for=condition=Ready=false --timeout=30s inferenceservice/${APP_NAME} || true
fi

kubectl wait --for=condition=Ready --timeout=600s inferenceservice/${APP_NAME}
prediction_url="$(kubectl get inferenceservice/${APP_NAME} -o jsonpath='{.status.url}')/${PROTOCOL_VERSION}/models/${prediction_url_path}"
printf "${prediction_url}" > /tekton/results/${TASK_RESULT}

# Now, register the new application within fuseml

inside_metadata=""
first_resource=1
envsubst < /root/template.sh | while read -r line
do
  if echo "$line" | grep -q '^[ ]*kind'; then
      inside_metadata=""
      if [[ $first_resource == 0 ]] ; then
          echo -n ", " >> /tmp/resources.json
      else
          first_resource=0
      fi
      echo -n "{$line" | sed -E 's/([^ \t:{]+)/"\1"/g' >> /tmp/resources.json
  fi
  if echo "$line" | grep -q '^[ ]*metadata:' ; then
      inside_metadata="yes"
  fi
  if echo "$line" | grep -q '^[ ]*name:' && [[ -n $inside_metadata ]] ; then
      echo -n ", $line}" | sed -E 's/([^ \t:,}]+)/"\1"/g' >> /tmp/resources.json
  fi
done

resources=$(< /tmp/resources.json tr -s '"')
rm /tmp/resources.json

curl -X POST -H "Content-Type: application/json"  http://fuseml-core.fuseml-core.svc.cluster.local:80/applications -d "{\"name\":\"$APP_NAME\",\"description\":\"Application generated by $FUSEML_ENV_WORKFLOW_NAME workflow\", \"type\":\"predictor\",\"url\":\"$prediction_url\",\"workflow\":\"$FUSEML_ENV_WORKFLOW_NAME\", \"k8s_namespace\": \"$FUSEML_ENV_WORKFLOW_NAMESPACE\", \"k8s_resources\": [ $resources ]}"
