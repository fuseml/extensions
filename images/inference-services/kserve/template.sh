---
apiVersion: v1
kind: Secret
metadata:
  name: "${APP_NAME}-storage"
  annotations:
     serving.kserve.io/s3-endpoint: ${S3_ENDPOINT}
     serving.kserve.io/s3-usehttps: "0"
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}
  AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: "${APP_NAME}-kserve"
secrets:
  - name: "${APP_NAME}-storage"
---
apiVersion: "serving.kserve.io/v1beta1"
kind: "InferenceService"
metadata:
  name: "${APP_NAME}"
  labels:
    fuseml/app-name: "${PROJECT}"
    fuseml/org: "${ORG}"
    fuseml/workflow: "${FUSEML_ENV_WORKFLOW_NAME}"
    fuseml/app-guid: "${ORG}.${PROJECT}.${FUSEML_ENV_WORKFLOW_NAME}"
spec:
  predictor:
    serviceAccountName: "${APP_NAME}-kserve"
    timeout: 60
    ${PREDICTOR}:
      protocolVersion: ${PROTOCOL_VERSION}
      runtimeVersion: ${RUNTIME_VERSION}
      storageUri: "${FUSEML_MODEL}"
      args: ${ARGS}
      resources:
        limits: ${RESOURCES_LIMITS}
        requests:
          cpu: 100m
          memory: 128Mi