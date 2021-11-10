ARG BASE_PREDICTOR_IMAGE=ghcr.io/fuseml/base-predictor

FROM golang:1.15-alpine as minio-builder

ENV GOPATH /go
ENV CGO_ENABLED 0
ENV GO111MODULE on

RUN apk add --no-cache git && \
  git clone https://github.com/minio/mc && cd mc && \
  go install -v -ldflags "$(go run buildscripts/gen-ldflags.go)"

FROM $BASE_PREDICTOR_IMAGE

COPY --from=minio-builder /go/bin/mc /usr/bin/mc
COPY --from=minio-builder /go/mc/CREDITS /licenses/CREDITS
COPY --from=minio-builder /go/mc/LICENSE /licenses/LICENSE

ENV FUSEML_ENV_WORKFLOW_NAMESPACE fuseml-workloads
ENV FUSEML_ENV_WORKFLOW_NAME ""
ENV FUSEML_APP_NAME ""
ENV FUSEML_VERBOSE false
ENV FUSEML_RESOURCES_LIMITS ""
ENV FUSEML_MODEL ""
ENV FUSEML_PREDICTOR "auto"
ENV FUSEML_RUNTIME_VERSION ""
ENV AWS_ACCESS_KEY_ID ""
ENV AWS_SECRET_ACCESS_KEY ""
ENV MLFLOW_S3_ENDPOINT_URL ""

COPY run.sh /usr/local/bin/run

RUN mkdir /opt/kserve/
COPY templates /opt/kserve/templates

CMD [ "run" ]
