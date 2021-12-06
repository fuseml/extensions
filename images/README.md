# FuseML Workflow Extensions

This folder contains a set of container images implementing various FuseML workflow steps maintained by the FuseML team:

- [MLFlow builder](builders/mlflow/) - builds python runtime environment container images for codesets that are structured according to the [MLFlow Project format](https://www.mlflow.org/docs/latest/projects.html).
- [KServe predictor](inference-services/kserve/) - deploys models using the [KServe inference platform](https://kserve.github.io/website/).
- [Seldon Core predictor](inference-services/seldon-core/) - deploys ML models using the [Seldon Core MLOps platform](https://docs.seldon.io/projects/seldon-core/en/latest/).
- [OVMS converter](converters/ovms/) and [predictor](inference-services/ovms/) - can be used to optimize and convert ML models into the Intel IR format with the [OpenVINO Model Optimizer](https://docs.openvino.ai/latest/openvino_docs_MO_DG_Deep_Learning_Model_Optimizer_DevGuide.html) and then deploy them using the [OpenVINO Model Server](https://docs.openvino.ai/latest/openvino_docs_ovms.html).
