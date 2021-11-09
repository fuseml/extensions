#!/bin/bash

# Patch the KNative domain configuration with the domain pointing to the Istio ingress gateway.
# This is computed as follows:
# * if a custom domain was used to install FuseML and FuseML is also using Istio, use that domain
# * otherwise, compute the domain as an nip.io subdomain from the Istio ingress gateway load balancer IP address
ISTIO_DOMAIN=$(kubectl get virtualservice fuseml-core -n fuseml-core -o=jsonpath='{.spec.hosts[0]}' | sed -e "s/fuseml-core\.//")
ISTIO_LB_IP=$(kubectl -n istio-system get service istio-ingressgateway -o=jsonpath='{.status.loadBalancer.ingress[0].ip}')
if [ -z "$ISTIO_DOMAIN" ]; then
  if [ ! -z "$ISTIO_LB_IP" ]; then
    ISTIO_DOMAIN="$ISTIO_LB_IP.nip.io"
  else
    echo "WARNING: could not update the KNative domain configuration with a domain matching the Istio ingress gateway !"
    exit
  fi
fi


# Patch the Knative config with the domain. Retries 5 times with a 3s delay between each attempt,
# as the net-istio config validation webhook might not be ready yet.
retries=0
until [ "$retries" -ge 5 ]
do
   kubectl -n knative-serving patch configmap config-domain --type merge \
    -p "{\"data\":{\"$ISTIO_DOMAIN\":\"\"}}" && break
   retries=$((retries+1)) 
   sleep 3
done



