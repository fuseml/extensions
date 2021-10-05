FROM alpine as builder

ENV KUBE_LATEST_VERSION="v1.20.5"
ENV YQ_LATEST_VERSION="v4.13.3"

RUN apk add --update --no-cache ca-certificates curl jq \
  && export ARCH="$(uname -m)" \
  && export OS=$(uname|tr '[:upper:]' '[:lower:]') \
  && if [[ ${ARCH} == "x86_64" ]]; then export ARCH="amd64"; fi \
  && if [[ ${ARCH} == "aarch64" ]]; then export ARCH="arm64"; fi \
  && curl -L https://dl.min.io/client/mc/release/${OS}-${ARCH}/mc -o /usr/local/bin/mc \
  && chmod +x /usr/local/bin/mc \
  && curl -L https://github.com/mikefarah/yq/releases/download/${YQ_LATEST_VERSION}/yq_${OS}_${ARCH} -o /usr/local/bin/yq \
  && chmod +x /usr/local/bin/yq

FROM openvino/ubuntu18_dev:2021.4.1

USER root

COPY --from=builder /usr/local/bin/mc /usr/local/bin/mc
COPY --from=builder /usr/bin/jq /usr/local/bin/jq
COPY --from=builder /usr/local/bin/yq /usr/local/bin/yq

COPY run.sh /usr/local/bin/run

RUN mkdir -p /opt/fuseml/workspace \
  && chown openvino:users /opt/fuseml/workspace

USER openvino

ENV AWS_ACCESS_KEY_ID ""
ENV AWS_SECRET_ACCESS_KEY ""
ENV S3_ENDPOINT "https://s3.amazonaws.com"
ENV FUSEML_MODEL ""
ENV FUSEML_MODEL_FORMAT "auto"
ENV FUSEML_INPUT_SHAPE ""


CMD [ "run" ]
