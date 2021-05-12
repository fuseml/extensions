#!/bin/sh

set -e
set -u
set -o pipefail

# load org and project from repository if exists,
# if not, set them as a random string
if [ -e ".fuseml/_project" ]; then
    export ORG=$(cat .fuseml/_org)
    export PROJECT=$(cat .fuseml/_project)
else
    export ORG=$(tr -dc a-z0-9 </dev/urandom | head -c 6 ; echo '')
    export PROJECT=$(tr -dc a-z0-9 </dev/urandom | head -c 6 ; echo '')
fi

# kfserving expects the model file as model.joblib however mlflow
# saves the model as model.pkl, so if there is no model.joblib,
# create a copy named model.joblib from model.pkl
mc alias set minio http://mlflow-minio:9000 ${AWS_ACCESS_KEY_ID} ${AWS_SECRET_ACCESS_KEY}
model_bucket="minio${FUSEML_MODEL//s3:\//}"
if ! mc ls ${model_bucket} | grep -q "model.joblib"; then
    mc cp ${model_bucket}/model.pkl ${model_bucket}/model.joblib
fi

envsubst < /root/template.sh | kubectl apply -f -

isvc="${ORG}-${PROJECT}"
kubectl wait --for=condition=Ready --timeout=600s inferenceservice/${isvc}
prediction_url="$(kubectl get inferenceservice/${isvc} -o jsonpath='{.status.url}')/v2/models/${isvc}/infer"
printf "${prediction_url}" > /tekton/results/${TASK_RESULT}

# Now, register the new application within fuseml

inside_metadata=""
first_resource=1
envsubst < /root/template.sh | while read line
do
  if echo $line | grep -q '^[ ]*kind'; then
      inside_metadata=""
      if [[ $first_resource == 0 ]] ; then
          echo -n ", " >> /tmp/resources.json
      else
          first_resource=0
      fi
      echo -n "{$line" | sed -E 's/([^ \t:{]+)/"\1"/g' >> /tmp/resources.json
  fi
  if echo $line | grep -q '^[ ]*metadata:' ; then
      inside_metadata="yes"
  fi
  if echo $line | grep -q '^[ ]*name:' && [[ -n $inside_metadata ]] ; then
      echo -n ", $line}" | sed -E 's/([^ \t:,}]+)/"\1"/g' >> /tmp/resources.json
  fi
done

resources=$(cat /tmp/resources.json | tr -s '"')
rm /tmp/resources.json

curl -X POST -H "Content-Type: application/json"  http://fuseml-core:80/applications -d "{\"name\":\"$isvc\",\"type\":\"predictor\",\"url\":\"$prediction_url\",\"workflow\":\"$FUSEML_ENV_WORKFLOW_NAME\", \"k8s_namespace\": \"$FUSEML_ENV_WORKFLOW_NAMESPACE\", \"k8s_resources\": [ $resources ]}"
