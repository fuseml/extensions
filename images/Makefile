# Container registry (default to dockerhub) 
REGISTRY ?= registry.hub.docker.com/library

MLFLOW_BUILDER_REPO ?= mlflow-builder
BASE_PREDICTOR_REPO ?= base-predictor
KFSERVING_PREDICTOR_REPO ?= kfserving-predictor
SELDON_PREDICTOR_REPO ?= seldon-core-predictor
OVMS_PREDICTOR_REPO ?= ovms-predictor
OVMS_CONVERTER_REPO ?= ovms-converter
MLFLOW_REPO ?= mlflow
MLFLOW_VERSION ?= 1.20.2

GIT_REF = $(shell git symbolic-ref -q --short HEAD || git describe --tags --abbrev=0 --exact-match)

ifdef VERSION
	IMAGE_TAG = $(VERSION)
else
# Use `latest` as a default version value when compiling in the main branch
ifeq ($(GIT_REF),main)
	IMAGE_TAG = latest
# Use the reference name as a default version value when compiling in another branch/tag,
else
	IMAGE_TAG = $(GIT_REF)
endif
endif

BASE_PREDICTOR_IMAGE ?= $(REGISTRY)/$(BASE_PREDICTOR_REPO):$(IMAGE_TAG)

all: docker-build 

docker-build: docker-build-extensions docker-build-mlflow

docker-push: docker-push-extensions docker-push-mlflow

docker-release: docker-release-extensions docker-release-mlflow

docker-build-builder-mlflow:
	docker build ./builders/mlflow -t ${REGISTRY}/${MLFLOW_BUILDER_REPO}:${IMAGE_TAG}

docker-build-predictor-base:
	docker build ./inference-services/base -t ${REGISTRY}/${BASE_PREDICTOR_REPO}:${IMAGE_TAG}

docker-build-predictor-kfserving:
	docker build ./inference-services/kfserving -t ${REGISTRY}/${KFSERVING_PREDICTOR_REPO}:${IMAGE_TAG}

docker-build-predictor-seldon:
	docker build ./inference-services/seldon-core -t ${REGISTRY}/${SELDON_PREDICTOR_REPO}:${IMAGE_TAG}

docker-build-predictor-ovms: docker-build-predictor-base
	docker build ./inference-services/ovms -t ${REGISTRY}/${OVMS_PREDICTOR_REPO}:${IMAGE_TAG} --build-arg BASE_PREDICTOR_IMAGE=${BASE_PREDICTOR_IMAGE}

docker-build-converter-ovms:
	docker build ./converters/ovms -t ${REGISTRY}/${OVMS_CONVERTER_REPO}:${IMAGE_TAG}

# Build the docker images for workflow extensions
docker-build-extensions: docker-build-builder-mlflow \
                         docker-build-predictor-kfserving \
                         docker-build-predictor-seldon \
                         docker-build-predictor-ovms \
                         docker-build-converter-ovms

# Build the docker image for the MLFlow tracking service
docker-build-mlflow:
	docker build ./mlflow -t ${REGISTRY}/${MLFLOW_REPO}:${MLFLOW_VERSION} --build-arg MLFLOW_VERSION="$(MLFLOW_VERSION)"

docker-push-builder-mlflow: docker-build-builder-mlflow
	docker build ./builders/mlflow -t ${REGISTRY}/${MLFLOW_BUILDER_REPO}:${IMAGE_TAG}

docker-push-predictor-base: docker-build-predictor-base
	docker push ${REGISTRY}/${BASE_PREDICTOR_REPO}:${IMAGE_TAG}

docker-push-predictor-kfserving: docker-build-predictor-kfserving
	docker push ${REGISTRY}/${KFSERVING_PREDICTOR_REPO}:${IMAGE_TAG}

docker-push-predictor-seldon: docker-build-predictor-seldon
	docker push ${REGISTRY}/${SELDON_PREDICTOR_REPO}:${IMAGE_TAG}

docker-push-predictor-ovms: docker-build-predictor-ovms
	docker push ${REGISTRY}/${OVMS_PREDICTOR_REPO}:${IMAGE_TAG}

docker-push-converter-ovms: docker-build-converter-ovms
	docker push ${REGISTRY}/${OVMS_CONVERTER_REPO}:${IMAGE_TAG}

# Build and push the docker images for workflow extensions
docker-push-extensions: docker-push-builder-mlflow \
                        docker-push-predictor-base \
                        docker-push-predictor-kfserving \
                        docker-push-predictor-seldon \
                        docker-push-predictor-ovms \
                        docker-push-converter-ovms

# Build and push the docker image for the MLFlow tracking service
docker-push-mlflow: docker-build-mlflow
	docker push ${REGISTRY}/${MLFLOW_REPO}:${MLFLOW_VERSION}

docker-release-builder-mlflow:
	docker buildx build ./builders/mlflow -t ${REGISTRY}/${MLFLOW_BUILDER_REPO}:${IMAGE_TAG} --platform linux/amd64,linux/arm64 --push

docker-release-predictor-base:
	docker buildx build ./inference-services/base -t ${REGISTRY}/${BASE_PREDICTOR_REPO}:${IMAGE_TAG} --platform linux/amd64,linux/arm64 --push

docker-release-predictor-kfserving:
	docker buildx build ./inference-services/kfserving -t ${REGISTRY}/${KFSERVING_PREDICTOR_REPO}:${IMAGE_TAG} --platform linux/amd64,linux/arm64 --push

docker-release-predictor-seldon:
	docker buildx build ./inference-services/seldon-core -t ${REGISTRY}/${SELDON_PREDICTOR_REPO}:${IMAGE_TAG} --platform linux/amd64,linux/arm64 --push

docker-release-predictor-ovms: docker-release-predictor-base
	docker buildx build ./inference-services/ovms -t ${REGISTRY}/${OVMS_PREDICTOR_REPO}:${IMAGE_TAG} --build-arg BASE_PREDICTOR_IMAGE=${BASE_PREDICTOR_IMAGE} --platform linux/amd64,linux/arm64 --push

docker-release-converter-ovms:
	docker buildx build ./converters/ovms -t ${REGISTRY}/${OVMS_CONVERTER_REPO}:${IMAGE_TAG} --platform linux/amd64 --push

# Build and release multi-arch docker images for workflow extensions
docker-release-extensions: docker-release-builder-mlflow \
                           docker-release-predictor-base \
                           docker-release-predictor-kfserving \
                           docker-release-predictor-seldon \
                           docker-release-predictor-ovms \
                           docker-release-converter-ovms

# Build and release multi-arch docker images for workflow extensions
docker-release-mlflow:
	docker buildx build ./mlflow -t ${REGISTRY}/${MLFLOW_REPO}:${MLFLOW_VERSION} --build-arg MLFLOW_VERSION="$(MLFLOW_VERSION)" --platform linux/amd64,linux/arm64 --push
