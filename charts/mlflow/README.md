````
helm install mlflow . --namespace mlflow --create-namespace --dependency-update \
  --set ingress.hosts='{mlflow.10.160.5.140.nip.io}',minio.ingress.hosts='{minio.10.160.5.140.nip.io}'
````
