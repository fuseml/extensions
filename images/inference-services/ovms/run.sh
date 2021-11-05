#!/bin/sh

set -e
set -u
set -o pipefail

$FUSEML_VERBOSE && set -x

. /opt/fuseml/scripts/helpers.sh

# load org and project from repository if exists,
# if not, set them as a random string
if [ -e ".fuseml/_project" ]; then
    ORG=$(cat .fuseml/_org)
    PROJECT=$(cat .fuseml/_project)
else
    ORG=$(head /dev/urandom | LC_ALL=C tr -dc a-z0-9 | head -c 6)
    PROJECT=$(head /dev/urandom | LC_ALL=C tr -dc a-z0-9 | head -c 6)
fi
APP_NAME="${ORG}-${PROJECT}-${FUSEML_ENV_WORKFLOW_NAME}"

[ -n "$FUSEML_APP_NAME" ] && APP_NAME=$FUSEML_APP_NAME

NAMESPACE=${FUSEML_ENV_WORKFLOW_NAMESPACE}
OVMS_ISTIO_GATEWAY=ovms-gateway

# Extracting the domain name is done by looking at the Istio Gateway created in the
# same namespace by the OVMS installer extension and extracting the domain out of the
# host wildcard configured in the form of '*.<domain>'
DOMAIN=$(kubectl get Gateway ${OVMS_ISTIO_GATEWAY} -n ${NAMESPACE} -o jsonpath='{.spec.servers[0].hosts[0]}')
ISTIO_HOST="${APP_NAME}${DOMAIN/\*/}"

RESOURCES=null
# set inference service container resources if specified
if [ -n "${FUSEML_RESOURCES}" ]; then
    RESOURCES="${FUSEML_RESOURCES}"
fi

cat << EOF > /opt/openvino/templates/values.yaml
#@data/values
---
namespace: "${NAMESPACE}"
name_suffix: "${APP_NAME}"
labels:
  fuseml/app-name: "${APP_NAME}"
  fuseml/org: "${ORG}"
  fuseml/app-guid: "${ORG}.${PROJECT}.${FUSEML_ENV_WORKFLOW_NAME}"
  fuseml/workflow: "${FUSEML_ENV_WORKFLOW_NAME}"
ovms_image_tag: "${FUSEML_OVMS_IMAGE_TAG}"
aws_access_key_id: "${AWS_ACCESS_KEY_ID}"
aws_secret_access_key: "${AWS_SECRET_ACCESS_KEY}"
s3_compat_api_endpoint: "${S3_ENDPOINT}"
model_path: "${FUSEML_MODEL}"
model_name: "${FUSEML_MODEL_NAME}"
istio_host: "${ISTIO_HOST}"
istio_gateway: "${OVMS_ISTIO_GATEWAY}"
nireq: "${FUSEML_NIREQ}"
plugin_config: '${FUSEML_PLUGIN_CONFIG//\"/\\\"}'
batch_size: "${FUSEML_BATCH_SIZE}"
shape: "${FUSEML_SHAPE}"
layout: "${FUSEML_LAYOUT}"
replicas: ${FUSEML_REPLICAS}
resources: ${RESOURCES}
target_device: "${FUSEML_TARGET_DEVICE}"
EOF

$FUSEML_VERBOSE && cat /opt/openvino/templates/values.yaml

new_instance=true
if kubectl get "ovms/ovms-${APP_NAME}" -n "${FUSEML_ENV_WORKFLOW_NAMESPACE}" > /dev/null 2>&1; then
    new_instance=false
fi

ytt -f /opt/openvino/templates/ | kubectl apply -f -

if $new_instance; then
    kubectl wait --for=condition=Deployed=true --timeout=30s \
      "ovms/ovms-${APP_NAME}" -n "${FUSEML_ENV_WORKFLOW_NAMESPACE}"

    # rollout fails if the deployment does not exist yet, so we need to wait until it is created
    count=0
    until kubectl get "deploy/ovms-${APP_NAME}" -n "${FUSEML_ENV_WORKFLOW_NAMESPACE}" > /dev/null 2>&1; do
        count=$((count + 1))
        if [[ ${count} -eq "30" ]]; then
            echo "Timed out waiting for deploy/ovms-${APP_NAME} to be created"
            exit 1
        fi
        sleep 2
    done
else
    # if this isn't a new deployment, we need to make sure we check the status
    # of the new deployment revision instead of the old one; the only way to achieve that
    # while keeping everything simple and accounting for all corner cases
    # (e.g. no changes applied and/or previous deployment was/wasn't successful) is
    # to wait a few seconds, to give the new deployment a chance to start the update
    sleep 30
fi

kubectl wait --for=condition=Available=true --timeout=30s \
  "deploy/ovms-${APP_NAME}" -n "${FUSEML_ENV_WORKFLOW_NAMESPACE}"
kubectl rollout status "deploy/ovms-${APP_NAME}" -n "${FUSEML_ENV_WORKFLOW_NAMESPACE}" --timeout=2m

prediction_url="http://${ISTIO_HOST}/v1/models/${FUSEML_MODEL_NAME}:${FUSEML_PREDICTION_TYPE}"

echo "${prediction_url}" > "/tekton/results/${TASK_RESULT}"

# Now, register the new application within fuseml; use kubectl only to format the output correctly
ytt -f /opt/openvino/templates/ | kubectl apply -f - --dry-run=client -o json | register_fuseml_app \
  --name "${APP_NAME}" \
  --desc "OVMS service deployed for ${FUSEML_MODEL}" \
  --url "${prediction_url}" \
  --type predictor
