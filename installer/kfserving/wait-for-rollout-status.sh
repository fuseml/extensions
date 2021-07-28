#!/bin/bash

kubectl rollout status statefulset/kfserving-controller-manager -n kfserving-system
