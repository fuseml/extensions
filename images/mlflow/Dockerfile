FROM continuumio/miniconda3 AS build

ARG MLFLOW_VERSION=1.20.2

RUN conda install -c conda-forge conda-pack 

RUN conda create --name mlflow -c conda-forge mlflow=$MLFLOW_VERSION pymysql psycopg2 boto3

RUN conda-pack -n mlflow -o /tmp/env.tar && \
  mkdir /venv && cd /venv && tar xf /tmp/env.tar && \
  rm /tmp/env.tar

RUN /venv/bin/conda-unpack

FROM debian:buster AS runtime

COPY --from=build /venv /venv

ENV LC_ALL C.UTF-8
ENV LANG C.UTF-8
ENV BACKEND_URI sqlite:////mlflow/mlflow.db
ENV ARTIFACT_ROOT /mlflow/artifacts
ENV WORKERS 4

EXPOSE 80

SHELL ["/bin/bash", "-c"]
ENTRYPOINT source /venv/bin/activate && mlflow server --workers ${WORKERS} --backend-store-uri ${BACKEND_URI} --default-artifact-root ${ARTIFACT_ROOT} --host 0.0.0.0 --port 80 --expose-prometheus ${PROMETHEUS_METRICS:-''}

