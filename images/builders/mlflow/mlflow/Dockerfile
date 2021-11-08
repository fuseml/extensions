ARG BASE=conda
ARG MINICONDA_VERSION=4.10.3
ARG CONDA_BASE_IMAGE=continuumio/miniconda3:${MINICONDA_VERSION}
ARG INTEL_BASE_IMAGE=intel/intel-optimized-tensorflow:latest
ARG BASE_IMAGE=python:3.6.13

# intel based image needs to pip install from requirements.txt
# (because it has some requirements preinstalled with pip already)
FROM ${INTEL_BASE_IMAGE} as intel

ENV PIP_NO_CACHE_DIR=off

ONBUILD COPY requirements.txt /
ONBUILD RUN apt-get update && apt-get -y install git && \
    pip install --upgrade pip && pip install -r requirements.txt


# generic image with pip
FROM ${BASE_IMAGE} as requirements

ENV PIP_NO_CACHE_DIR=off

ONBUILD COPY requirements.txt /
ONBUILD RUN apt-get update && apt-get -y install git && \
    pip install --upgrade pip && pip install -r requirements.txt

# conda based image
FROM ${CONDA_BASE_IMAGE} as conda

ONBUILD COPY conda.yaml /env/

ENV PIP_NO_CACHE_DIR=off
ENV BASH_ENV /root/.bashrc

ONBUILD RUN env=$(awk '/name:/ {print $2}' /env/conda.yaml) && \
  printf ". /opt/conda/etc/profile.d/conda.sh\nconda activate ${env}" > /root/.bashrc && \
  conda env create -f /env/conda.yaml && \
  conda install -n ${env} boto3 && \
  find /opt/conda/ -follow -type f -name '*.a' -delete && \
  find /opt/conda/ -follow -type f -name '*.js.map' -delete && \
  conda clean -afy

# shared commands
FROM ${BASE}

COPY .fuseml/run.sh /usr/local/bin/run
COPY .fuseml/mlflow_run.py /usr/local/bin/mlflow_run

WORKDIR /workspace

ENV PYTHONUNBUFFERED=x
ENV FUSEML_MLFLOW_EXPERIMENT ""
ENV FUSEML_MLFLOW_ENTRYPOINT main
ENV FUSEML_MLFLOW_ENTRYPOINT_ARGS ""
ENV FUSEML_MLFLOW_ARTIFACT_PATH "model"

CMD [ "run" ]
