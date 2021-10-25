ARG MINICONDA_VERSION=4.10.3
ARG CONDA_BASE_IMAGE=continuumio/miniconda3:${MINICONDA_VERSION}
ARG BASE=conda
ARG INTEL_BASE_IMAGE=intel/intel-optimized-tensorflow-avx512

# conda not present in the intel image, so let's install it now
FROM ${INTEL_BASE_IMAGE} as intel

# need to set ARG again after FROM
ARG MINICONDA_VERSION
ENV MINICONDA_VERSION=$MINICONDA_VERSION

ONBUILD RUN apt-get update && apt-get -y install curl git && \
    echo "Version $MINICONDA_VERSION" && \
    curl -L -o miniconda_installer.sh https://repo.anaconda.com/miniconda/Miniconda3-py38_${MINICONDA_VERSION}-Linux-x86_64.sh && \
    chmod +x miniconda_installer.sh && \
    sh miniconda_installer.sh -b -p /opt/conda && \
    rm miniconda_installer.sh && \
    ln -s /opt/conda/bin/conda /usr/local/bin/conda

# nothing to add for non-intel case
FROM ${CONDA_BASE_IMAGE} as conda

# shared commands
FROM ${BASE}

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
