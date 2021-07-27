#!/bin/bash

kubectl wait --for=condition=available --timeout=600s deployment/cert-manager-webhook -n cert-manager
