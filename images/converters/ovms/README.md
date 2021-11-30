# OpenVINO Model Server converter extension for FuseML workflows

The Dockerfile and associated files in this folder implement the FuseML OVMS converter workflow step. The OVMS converter workflow step can be used to convert input ML models to the IR (Intermediate Representation) format supported by the [OpenVINO Model Server](https://docs.openvino.ai/latest/openvino_docs_ovms.html). It is normally used in combination with the [OVMS predictor workflow step](../../inference-services/ovms/) in FuseML workflows to serve input ML models with the OpenVINO Model Server. The OVMS converter workflow extension is implemented using the [OpenVINO Model Optimizer](https://docs.openvino.ai/latest/openvino_docs_MO_DG_Deep_Learning_Model_Optimizer_DevGuide.html).

For more information on what this workflow step does and how it can be used, see the [FuseML documentation](https://fuseml.github.io/docs/dev/workflows/ovms-converter/).
