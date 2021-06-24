
FROM alpine

ENV FUSEML_FILES=/fuseml-dockerfiles

COPY mlflow ${FUSEML_FILES}/

COPY run.sh /usr/local/bin/run

ENTRYPOINT [ "run" ]
	
