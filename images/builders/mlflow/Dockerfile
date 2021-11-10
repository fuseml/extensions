FROM gcr.io/kaniko-project/executor:v1.7.0 AS kaniko

FROM alpine:latest

COPY --from=kaniko /kaniko /kaniko
ENV HOME /root
ENV USER root
ENV PATH $PATH:/usr/local/bin:/kaniko
ENV DOCKER_CONFIG /kaniko/.docker/

WORKDIR /workspace

RUN apk add --no-cache ca-certificates jq curl unzip

RUN export ARCH="$(uname -m)" \
  && export OS=$(uname|tr '[:upper:]' '[:lower:]') \
  && if [[ ${ARCH} == "x86_64" ]]; then export ARCH="amd64"; fi \
  && if [[ ${ARCH} == "aarch64" ]]; then export ARCH="arm"; fi \
  && curl -LO https://github.com/mayflower/docker-ls/releases/latest/download/docker-ls-${OS}-${ARCH}.zip \
  && unzip docker-ls-${OS}-${ARCH}.zip -d /usr/local/bin \
  && rm docker-ls-${OS}-${ARCH}.zip \
  && rm -rf /var/spool

ENV MLFLOW_DOCKERFILE=/fuseml-mlflow

COPY mlflow/ ${MLFLOW_DOCKERFILE}/
COPY run.sh /usr/local/bin/run

# inject a value that is unique for every version of the built container image,
# to use it to reset the conda dependencies cache between image updates
RUN date +"%Y-%m-%d_%H-%M-%S" > /build-timestamp.txt

ENTRYPOINT ["run"]
