---
apiVersion: v1
kind: Secret
metadata:
  name: "${sd}-init-container-secret"
  annotations:
     serving.kubeflow.org/s3-endpoint: mlflow-minio:9000
     serving.kubeflow.org/s3-usehttps: "0"
type: Opaque
stringData:
  RCLONE_CONFIG_S3_TYPE: s3
  RCLONE_CONFIG_S3_PROVIDER: minio
  RCLONE_CONFIG_S3_ENV_AUTH: "false"
  RCLONE_CONFIG_S3_ACCESS_KEY_ID: ${AWS_ACCESS_KEY_ID}
  RCLONE_CONFIG_S3_SECRET_ACCESS_KEY: ${AWS_SECRET_ACCESS_KEY}
  RCLONE_CONFIG_S3_ENDPOINT: ${MLFLOW_S3_ENDPOINT_URL}
---
apiVersion: v1
kind: ServiceAccount
metadata:
  name: "${sd}-seldon"
secrets:
  - name: "${sd}-init-container-secret"
---
apiVersion: "machinelearning.seldon.io/v1alpha2"
kind: "SeldonDeployment"
metadata:
  name: "${sd}"
  labels:
    fuseml/app-name: "${PROJECT}"
    fuseml/org: "${ORG}"
    fuseml/workflow: "${FUSEML_ENV_WORKFLOW_NAME}"
    fuseml/app-guid: "${ORG}.${PROJECT}.${FUSEML_ENV_WORKFLOW_NAME}"
  annotations:
    "seldon.io/istio-host": "${ISTIO_HOST}"
    "seldon.io/istio-gateway": "${FUSEML_ENV_WORKFLOW_NAMESPACE}/seldon-gateway"
spec:
  name: "${sd}"
  protocol: "${PROTOCOL}"
  predictors:
    - name: "predictor"
      labels:
        fuseml/app-name: "${PROJECT}"
        fuseml/org: "${ORG}"
        fuseml/workflow: "${FUSEML_ENV_WORKFLOW_NAME}"
        fuseml/app-guid: "${ORG}.${PROJECT}.${FUSEML_ENV_WORKFLOW_NAME}"
      replicas: 1
      graph:
        children: []
        implementation: "${PREDICTOR_SERVER}"
        modelUri: "${FUSEML_MODEL}"
        envSecretRefName: "${sd}-init-container-secret"
        name: classifier
        serviceAccountName: "${sd}-seldon"
        parameters: ${PARAMETERS}
      componentSpecs:
        - spec:
            containers:
            - name: classifier
              livenessProbe:
                initialDelaySeconds: 120
                failureThreshold: 200
                periodSeconds: 5
                successThreshold: 1
                httpGet:
                  path: /health/ping
                  port: http
                  scheme: HTTP
