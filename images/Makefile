# Container registry (default to dockerhub) 
REGISTRY ?= registry.hub.docker.com/library

MLFLOW_BUILDER_REPO ?= mlflow-builder
KFSERVING_PREDICTOR_REPO ?= kfserving-predictor
MLFLOW_REPO ?= mlflow
MLFLOW_VERSION ?= 1.19.0

GIT_REF = $(shell git symbolic-ref -q --short HEAD || git describe --tags --abbrev=0 --exact-match)

ifdef VERSION
	IMAGE_TAG = $(VERSION)
else
# Use `dev` as a default version value when compiling in the main branch
ifeq ($(GIT_REF),main)
	IMAGE_TAG = dev
# Use the reference name as a default version value when compiling in another branch/tag,
else
	IMAGE_TAG = $(GIT_REF)
endif
endif

all: docker-build 

docker-build: docker-build-extensions docker-build-mlflow

docker-push: docker-push-extensions docker-push-mlflow

# Build the docker images for workflow extensions
docker-build-extensions:
	docker build ./builders/mlflow -t ${REGISTRY}/${MLFLOW_BUILDER_REPO}:${IMAGE_TAG}
	docker build ./inference-services/kfserving -t ${REGISTRY}/${KFSERVING_PREDICTOR_REPO}:${IMAGE_TAG}

# Build the docker image for the MLFlow tracking service
docker-build-mlflow:
	docker build ./mlflow -t ${REGISTRY}/${MLFLOW_REPO}:${MLFLOW_VERSION} --build-arg MLFLOW_VERSION="$(MLFLOW_VERSION)"

# Push the docker images for workflow extensions
docker-push-extensions:
	docker push ${REGISTRY}/${MLFLOW_BUILDER_REPO}:${IMAGE_TAG}
	docker push ${REGISTRY}/${KFSERVING_PREDICTOR_REPO}:${IMAGE_TAG}

# Push the docker image for the MLFlow tracking service
docker-push-mlflow:
	docker push ${REGISTRY}/${MLFLOW_REPO}:${MLFLOW_VERSION}
