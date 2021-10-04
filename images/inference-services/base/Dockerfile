FROM alpine

ENV KUBE_LATEST_VERSION="v1.20.5"
ENV YTT_LATEST_VERSION="v0.36.0"

RUN apk add --update --no-cache ca-certificates curl jq \
  && export ARCH="$(uname -m)" \
  && export OS=$(uname|tr '[:upper:]' '[:lower:]') \
  && if [[ ${ARCH} == "x86_64" ]]; then export ARCH="amd64"; fi \
  && if [[ ${ARCH} == "aarch64" ]]; then export ARCH="arm64"; fi \
  && curl -L https://storage.googleapis.com/kubernetes-release/release/${KUBE_LATEST_VERSION}/bin/${OS}/${ARCH}/kubectl -o /usr/local/bin/kubectl \
  && chmod +x /usr/local/bin/kubectl \
  && curl -L https://github.com/vmware-tanzu/carvel-ytt/releases/download/${YTT_LATEST_VERSION}/ytt-${OS}-${ARCH} -o /usr/local/bin/ytt \
  && chmod +x /usr/local/bin/ytt

RUN mkdir -p /opt/fuseml/
COPY scripts /opt/fuseml/scripts
