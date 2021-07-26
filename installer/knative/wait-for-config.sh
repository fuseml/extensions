#!/bin/bash

kubectl wait --for=condition=available --timeout=600s deployment -l networking.knative.dev/ingress-provider=istio -n knative-serving
