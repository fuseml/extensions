---
apiVersion: v1
kind: Secret
metadata:
  name: "${ORG}-${PROJECT}-storage"
  annotations:
     serving.kubeflow.org/s3-endpoint: ${S3_ENDPOINT}
     serving.kubeflow.org/s3-usehttps: "0"
type: Opaque
stringData:
  AWS_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}
  AWS_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: "${ORG}-${PROJECT}-kfserving"
secrets:
  - name: "${ORG}-${PROJECT}-storage"
---
apiVersion: "serving.kubeflow.org/v1beta1"
kind: "InferenceService"
metadata:
  name: "${ORG}-${PROJECT}"
  labels:
    fuseml/app-name: "${PROJECT}"
    fuseml/org: "${ORG}"
    fuseml/app-guid: "${ORG}.${PROJECT}"
spec:
  predictor:
    serviceAccountName: "${ORG}-${PROJECT}-kfserving"
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
