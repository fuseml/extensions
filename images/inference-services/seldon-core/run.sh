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

export PREDICTOR=${FUSEML_PREDICTOR}
if [ "${PREDICTOR}" = "auto" ]; then
    if ! mc stat ${model_bucket}/MLmodel &> /dev/null ; then
        echo "No MLmodel found, cannot auto detect predictor"
        exit 1
    fi

    PREDICTOR=$(mc cat ${model_bucket}/MLmodel | awk -F '.' '/loader_module:/ {print $2}')
fi

case $PREDICTOR in
    sklearn)
        if ! mc ls ${model_bucket} | grep -q "model.joblib"; then
            mc cp ${model_bucket}/model.pkl ${model_bucket}/model.joblib
        fi
        prediction_url_path="${APP_NAME}/api/v1.0/predictions"
        #TODO parametrize prediction method in workflow
        export PREDICTOR_SERVER="SKLEARN_SERVER"
        export PARAMETERS="[{ name: method, type: STRING, value: predict}]"
        export PROTOCOL=seldon
        ;;
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
        # second '${APP_NAME}' comes from spec.predictors.graph.name
        prediction_url_path="${APP_NAME}/v1/models/${APP_NAME}:predict"
        export PREDICTOR_SERVER="TENSORFLOW_SERVER"
        export PROTOCOL=tensorflow
        ;;
    triton)
        prediction_url_path="${APP_NAME}/v2/models/${APP_NAME}/infer"
        export PREDICTOR_SERVER="TRITON_SERVER"
        export FUSEML_MODEL="${FUSEML_MODEL}/triton"
        export PROTOCOL=kfserving
        if ! mc stat "${model_bucket}"/triton &> /dev/null ; then
            mlmodel=$(mc cat "${model_bucket}"/MLmodel)
            flavor="$(echo "${mlmodel}" | grep -E -o '^\s{2}([a-z].*[a-z])' | grep -v python_function | tr -d ' ')"
            echo $mlmodel
            echo $flavor
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

# Gateway has host info in the form of '*.seldon.172.18.0.2.nip.io' so we need to add a prefix
domain=$(kubectl get Gateway seldon-gateway -n ${FUSEML_ENV_WORKFLOW_NAMESPACE} -o jsonpath='{.spec.servers[0].hosts[0]}')
export ISTIO_HOST="${APP_NAME}${domain/\*/}"

envsubst < /root/template.sh > /tmp/kube-resources.yaml
$FUSEML_VERBOSE && cat /tmp/kube-resources.yaml
kubectl apply -f /tmp/kube-resources.yaml

# rollout fails if the object does not exist yet, so we need to wait until it is created
count=0
until [[ -n "$(kubectl get deploy -l seldon-deployment-id=${APP_NAME} -n ${FUSEML_ENV_WORKFLOW_NAMESPACE} 2>/dev/null)" ]]; do
  count=$((count + 1))
  if [[ ${count} -eq "30" ]]; then
    echo "Timed out waiting for Deployment to exist"
    exit 1
  fi
  sleep 2
done

kubectl rollout status deploy/$(kubectl get deploy -l seldon-deployment-id=${APP_NAME} -n ${FUSEML_ENV_WORKFLOW_NAMESPACE} -o jsonpath='{.items[0].metadata.name}') -n ${FUSEML_ENV_WORKFLOW_NAMESPACE}

prediction_url="http://${ISTIO_HOST}/seldon/${FUSEML_ENV_WORKFLOW_NAMESPACE}/${prediction_url_path}"

printf "${prediction_url}" > /tekton/results/${TASK_RESULT}

# Now, register the new application within fuseml

resources="{\"kind\": \"Secret\", \"name\": \"${APP_NAME}-init-container-secret\"}, {\"kind\": \"ServiceAccount\", \"name\": \"${APP_NAME}-seldon\"}, {\"kind\": \"SeldonDeployment\", \"name\": \"${APP_NAME}\"}"

curl -X POST -H "Content-Type: application/json"  http://fuseml-core.fuseml-core.svc.cluster.local:80/applications -d "{\"name\":\"$APP_NAME\",\"description\":\"Application generated by $FUSEML_ENV_WORKFLOW_NAME workflow\", \"type\":\"predictor\",\"url\":\"$prediction_url\",\"workflow\":\"$FUSEML_ENV_WORKFLOW_NAME\", \"k8s_namespace\": \"$FUSEML_ENV_WORKFLOW_NAMESPACE\", \"k8s_resources\": [ $resources ]}"
