
FROM ghcr.io/fuseml/mlflow:1.14.1

COPY conda.yaml /env/
RUN env=$(awk '/name:/ {print $2}' /env/conda.yaml) && \
	sed -i "s/base/$env/" /root/.bashrc

ENV BASH_ENV /root/.bashrc
RUN conda env create -f /env/conda.yaml

COPY .fuseml/run.sh /usr/local/bin/run

CMD [ "run" ]
	
