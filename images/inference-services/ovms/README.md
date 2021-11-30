# OpenVINO Model Server predictor extension for FuseML workflows

The Dockerfile and associated files in this folder implement the FuseML OVMS predictor workflow step. The OVMS predictor can be used to create and manage [OpenVINO Model Server inference servers](https://docs.openvino.ai/latest/openvino_docs_ovms.html) to serve input ML models as part of the execution of FuseML workflows. The OVMS predictor only accepts models in IR (Intermediate Representation) format as input. The [OVMS converter](../../converters/ovms/) workflow extension can be used to convert models to IR format.

For more information on what this workflow step does and how it can be used, see the [FuseML documentation](https://fuseml.github.io/docs/dev/workflows/ovms-predictor/).
