#!/bin/bash
CNI_PLUGIN_VERSION=1.1.1
CERTIFICATES_FOLDER=certs
for instance in worker-1 worker-2; do
  echo "[Step] Install CNI plugins"
  ssh ${instance} << EOF
    wget https://github.com/containernetworking/plugins/releases/download/v${CNI_PLUGIN_VERSION}/cni-plugins-linux-amd64-v${CNI_PLUGIN_VERSION}.tgz
    sudo tar -xzvf cni-plugins-linux-amd64-v${CNI_PLUGIN_VERSION}.tgz --directory /opt/cni/bin/
EOF
done
kubectl apply -f "https://cloud.weave.works/k8s/net?k8s-version=$(kubectl version | base64 | tr -d '\n')"
