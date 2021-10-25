ARG MINICONDA_VERSION=4.10.3
ARG BASE_IMAGE=continuumio/miniconda3:${MINICONDA_VERSION}

FROM ${BASE_IMAGE}

COPY conda.yaml /env/

ENV PIP_NO_CACHE_DIR=off
ENV BASH_ENV /root/.bashrc

RUN env=$(awk '/name:/ {print $2}' /env/conda.yaml) && \
  printf ". /opt/conda/etc/profile.d/conda.sh\nconda activate ${env}" > /root/.bashrc && \
  conda env create -f /env/conda.yaml && \
  conda install -n ${env} boto3 && \
  find /opt/conda/ -follow -type f -name '*.a' -delete && \
  find /opt/conda/ -follow -type f -name '*.js.map' -delete && \
  conda clean -afy

COPY .fuseml/run.sh /usr/local/bin/run

WORKDIR /workspace

CMD [ "run" ]
