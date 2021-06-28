#!/bin/sh

mkdir -p .fuseml
cp -rv ${FUSEML_FILES}/* .fuseml/ | awk '/Dockerfile/ {print $3}' | sed -e "s/[\r\n']//g"
