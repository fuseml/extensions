# MLflow python environment builder component for FuseML workflows

The Dockerfile and associated files in this folder implement the FuseML MLflow builder workflow step. The container image is based on [Kaniko](https://github.com/GoogleContainerTools/kaniko) and leverages the MLflow Project conventions to automate building MLflow runtime environments: container images used for the execution of MLflow augmented python code within a FuseML workflow.

For more information on what this workflow step does and how it can be used, see the [FuseML documentation](https://fuseml.github.io/docs/dev/workflows/mlflow-builder/).
