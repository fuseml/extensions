FROM gcr.io/kaniko-project/executor:v1.6.0 AS kaniko

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

# the registry value that is used by the builder step when pushing
# the built trainer image to the container registry
ENV FUSEML_REGISTRY registry.fuseml-registry
# the registry value used by consumers that need to pull the built
# trainer image (e.t. the container engine instances running on the cluster nodes).
#
# NOTE: sometimes, this value needs to be different than FUSEML_REGISTRY, for example
# when the container registry is accessed through different endpoints by the
# builder step and by the kubernetes cluster itself. In particular, when using the
# default internal FuseML registry, we need to reference the repository
# using the localhost address (see https://github.com/fuseml/fuseml/issues/65).
ENV FUSEML_PULL_REGISTRY 127.0.0.1:30500
ENV FUSEML_REPOSITORY mlflow/trainer
ENV FUSEML_MINICONDA_VERSION ""
ENV FUSEML_INTEL_OPTIMIZED false
ENV FUSEML_BASE_IMAGE ""
ENV FUSEML_VERBOSE false

ENTRYPOINT ["run"]
