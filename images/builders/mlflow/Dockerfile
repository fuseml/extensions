FROM gcr.io/kaniko-project/executor:v1.6.0 AS kaniko

FROM alpine:latest

COPY --from=kaniko /kaniko /kaniko
ENV HOME /root
ENV USER root
ENV PATH $PATH:/usr/local/bin:/kaniko
ENV DOCKER_CONFIG /kaniko/.docker/

WORKDIR /workspace

RUN apk add --no-cache ca-certificates jq curl unzip

RUN curl -LO https://github.com/mayflower/docker-ls/releases/latest/download/docker-ls-linux-amd64.zip \
  && unzip docker-ls-linux-amd64.zip -d /usr/local/bin \
  && rm docker-ls-linux-amd64.zip \
  && apk del curl unzip \
  && rm -rf /var/spool

ENV MLFLOW_DOCKERFILE=/fuseml-mlflow

COPY mlflow/ ${MLFLOW_DOCKERFILE}/
COPY run.sh /usr/local/bin/run

# inject a value that is unique for every version of the built container image,
# to use it to reset the conda dependencies cache between image updates
RUN date +"%Y-%m-%d_%H-%M-%S" > /build-timestamp.txt

ENTRYPOINT ["run"]
