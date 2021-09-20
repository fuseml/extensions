---
apiVersion: v1
kind: Secret
metadata:
  name: "${ORG}-${PROJECT}-init-container-secret"
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
  name: "${ORG}-${PROJECT}-seldon"
secrets:
  - name: "${ORG}-${PROJECT}-init-container-secret"
---
apiVersion: "machinelearning.seldon.io/v1alpha2"
kind: "SeldonDeployment"
metadata:
  name: "${ORG}-${PROJECT}"
  labels:
    fuseml/app-name: "${PROJECT}"
    fuseml/org: "${ORG}"
    fuseml/app-guid: "${ORG}.${PROJECT}"
  annotations:
    "seldon.io/istio-host": "${ISTIO_HOST}"
    "seldon.io/istio-gateway": "${FUSEML_ENV_WORKFLOW_NAMESPACE}/seldon-gateway"
spec:
  name: "${ORG}-${PROJECT}"
  predictors:
    - name: "predictor"
      labels:
        fuseml/app-name: "${PROJECT}"
        fuseml/org: "${ORG}"
        fuseml/app-guid: "${ORG}.${PROJECT}"
      replicas: 1
      graph:
        children: []
        implementation: "${PREDICTOR_SERVER}"
        modelUri: "${FUSEML_MODEL}"
        envSecretRefName: "${ORG}-${PROJECT}-init-container-secret"
        name: classifier
        serviceAccountName: "${ORG}-${PROJECT}-seldon"
        parameters:
          - name: method
            type: STRING
            value: predict
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
