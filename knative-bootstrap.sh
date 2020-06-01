#!/bin/bash

set -ex

# Install Knative serving CRDS and core
kubectl apply -f serving-crds.yaml
kubectl apply -f serving-core.yaml

# Download and unpack Istio
export ISTIO_VERSION=1.4.6
curl -L https://git.io/getLatestIstio | sh -
cd istio-${ISTIO_VERSION}

# Install CRDs
for i in install/kubernetes/helm/istio-init/files/crd*yaml; do kubectl apply -f $i; done

# Namespace creation
cat <<EOF | kubectl apply -f -
apiVersion: v1
kind: Namespace
metadata:
  name: istio-system
  labels:
    istio-injection: disabled
EOF

# A lighter template, with just pilot/gateway.
# Based on install/kubernetes/helm/istio/values-istio-minimal.yaml
helm template --namespace=istio-system \
  --set prometheus.enabled=false \
  --set mixer.enabled=false \
  --set mixer.policy.enabled=false \
  --set mixer.telemetry.enabled=false \
  `# Pilot doesn't need a sidecar.` \
  --set pilot.sidecar=false \
  --set pilot.resources.requests.memory=128Mi \
  `# Disable galley (and things requiring galley).` \
  --set galley.enabled=false \
  --set global.useMCP=false \
  `# Disable security / policy.` \
  --set security.enabled=false \
  --set global.disablePolicyChecks=true \
  `# Disable sidecar injection.` \
  --set sidecarInjectorWebhook.enabled=false \
  --set global.proxy.autoInject=disabled \
  --set global.omitSidecarInjectorConfigMap=true \
  --set gateways.istio-ingressgateway.autoscaleMin=1 \
  --set gateways.istio-ingressgateway.autoscaleMax=2 \
  `# Set pilot trace sampling to 100%` \
  --set pilot.traceSampling=100 \
  --set global.mtls.auto=false \
  install/kubernetes/helm/istio \
  > ./istio-lean.yaml

kubectl apply -f istio-lean.yaml

# Install Istio-controller
kubectl apply -f ../istio-controller.yaml 

# Apply xip.io jobs
kubectl apply -f ../serving-default-domain.yaml

# Installing simple app for Knative
kubectl apply -f ../knative-svc.yaml

# Check the deployment
kubectl get ksvc

# Curl when deployed
# curl $(kubectl get ksvc | awk '{print $2}' | grep hello)
