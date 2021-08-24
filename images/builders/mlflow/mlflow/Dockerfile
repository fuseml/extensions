FROM continuumio/miniconda3:4.10.3-alpine

COPY conda.yaml /env/

ENV PIP_NO_CACHE_DIR=off
ENV BASH_ENV /root/.bashrc

RUN apk add -q --no-cache git && \
  env=$(awk '/name:/ {print $2}' /env/conda.yaml) && \
  printf ". /opt/conda/etc/profile.d/conda.sh\nconda activate ${env}" > /root/.bashrc && \
  conda env create -f /env/conda.yaml && \
  conda install -n ${env} boto3 && \
  find /opt/conda/ -follow -type f -name '*.a' -delete && \
  find /opt/conda/ -follow -type f -name '*.js.map' -delete && \
  conda clean -afy

COPY .fuseml/run.sh /usr/local/bin/run

WORKDIR /workspace

CMD [ "run" ]

