#!/bin/bash
LOADBALANCER_ADDRESS=192.168.5.30
EXPIRES_IN=10000
CERTIFICATE_FOLDER=certs
CONFIG_FOLDER=kubeconfigs
K8S_VERSION=1.23.6

echo "[Step 0] Provisioning Kubelet Client Certificates"
for instance in worker-1 worker-2; do
  echo "Distribute the Kubernetes Configuration Files"
  scp ${CONFIG_FOLDER}/kube-proxy.kubeconfig ${instance}:~/
  cat > ${CERTIFICATE_FOLDER}/openssl-${instance}.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = ${instance}
IP.1 = $(getent hosts ${instance} | awk '{ print $1 }')
EOF
  openssl genrsa -out ${CERTIFICATE_FOLDER}/${instance}.key 2048
  openssl req -new -key ${CERTIFICATE_FOLDER}/${instance}.key -subj "/CN=system:node:${instance}/O=system:nodes" -out ${CERTIFICATE_FOLDER}/${instance}.csr -config ${CERTIFICATE_FOLDER}/openssl-${instance}.cnf
  openssl x509 -req -in ${CERTIFICATE_FOLDER}/${instance}.csr -CA ${CERTIFICATE_FOLDER}/ca.crt -CAkey ${CERTIFICATE_FOLDER}/ca.key -CAcreateserial  -out ${CERTIFICATE_FOLDER}/${instance}.crt -extensions v3_req -extfile ${CERTIFICATE_FOLDER}/openssl-${instance}.cnf -days ${EXPIRES_IN}

echo "[Step 1] The kubelet Kubernetes Configuration File"
  {
    kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=${CERTIFICATE_FOLDER}/ca.crt \
    --embed-certs=true \
    --server=https://${LOADBALANCER_ADDRESS}:6443 \
    --kubeconfig=${CONFIG_FOLDER}/${instance}.kubeconfig

    kubectl config set-credentials system:node:${instance} \
    --client-certificate=${CERTIFICATE_FOLDER}/${instance}.crt \
    --client-key=${CERTIFICATE_FOLDER}/${instance}.key \
    --embed-certs=true \
    --kubeconfig=${CONFIG_FOLDER}/${instance}.kubeconfig

    kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:node:${instance} \
    --kubeconfig=${CONFIG_FOLDER}/${instance}.kubeconfig

    kubectl config use-context default --kubeconfig=${CONFIG_FOLDER}/${instance}.kubeconfig
  }
  scp \
    ${CERTIFICATE_FOLDER}/ca.crt \
    ${CERTIFICATE_FOLDER}/${instance}.crt \
    ${CERTIFICATE_FOLDER}/${instance}.key \
    ${CONFIG_FOLDER}/${instance}.kubeconfig ${instance}:~/

  ssh ${instance} << HERE
    echo "[Step 2: ${instance}] Download and Install Worker Binaries ${instance}"
    wget -q --show-progress --https-only --timestamping \
      https://storage.googleapis.com/kubernetes-release/release/v${K8S_VERSION}/bin/linux/amd64/kubectl \
      https://storage.googleapis.com/kubernetes-release/release/v${K8S_VERSION}/bin/linux/amd64/kube-proxy \
      https://storage.googleapis.com/kubernetes-release/release/v${K8S_VERSION}/bin/linux/amd64/kubelet

    sudo mkdir -p \
      /etc/cni/net.d \
      /opt/cni/bin \
      /var/lib/kubelet \
      /var/lib/kube-proxy \
      /var/lib/kubernetes \
      /var/run/kubernetes

    {
      chmod +x kubectl kube-proxy kubelet
      sudo mv kubectl kube-proxy kubelet /usr/local/bin/
    }

    echo "[Step 3: ${instance}] Configure the Kubelet"
    {
      sudo mv \${HOSTNAME}.key \${HOSTNAME}.crt /var/lib/kubelet/
      sudo mv \${HOSTNAME}.kubeconfig /var/lib/kubelet/kubeconfig
      sudo mv ca.crt /var/lib/kubernetes/
    }

    cat <<EOF | sudo tee /var/lib/kubelet/kubelet-config.yaml
kind: KubeletConfiguration
apiVersion: kubelet.config.k8s.io/v1beta1
authentication:
  anonymous:
    enabled: false
  webhook:
    enabled: true
  x509:
    clientCAFile: "/var/lib/kubernetes/ca.crt"
authorization:
  mode: Webhook
clusterDomain: "cluster.local"
clusterDNS:
  - "10.96.0.10"
resolvConf: "/run/systemd/resolve/resolv.conf"
runtimeRequestTimeout: "15m"
EOF

    cat <<EOF | sudo tee /etc/systemd/system/kubelet.service
[Unit]
Description=Kubernetes Kubelet
Documentation=https://github.com/kubernetes/kubernetes
After=docker.service
Requires=docker.service

[Service]
ExecStart=/usr/local/bin/kubelet \\
  --config=/var/lib/kubelet/kubelet-config.yaml \\
  --image-pull-progress-deadline=2m \\
  --kubeconfig=/var/lib/kubelet/kubeconfig \\
  --tls-cert-file=/var/lib/kubelet/\${HOSTNAME}.crt \\
  --tls-private-key-file=/var/lib/kubelet/\${HOSTNAME}.key \\
  --network-plugin=cni \\
  --register-node=true \\
  --v=2
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    echo "[Step 4: ${instance}]  Configure the Kubernetes Proxy"
    cat <<EOF | sudo tee /var/lib/kube-proxy/kube-proxy-config.yaml
kind: KubeProxyConfiguration
apiVersion: kubeproxy.config.k8s.io/v1alpha1
clientConnection:
  kubeconfig: "/var/lib/kube-proxy/kubeconfig"
mode: "iptables"
clusterCIDR: "192.168.5.0/24"
EOF

    sudo mv kube-proxy.kubeconfig /var/lib/kube-proxy/kubeconfig

    cat <<EOF | sudo tee /etc/systemd/system/kube-proxy.service
[Unit]
Description=Kubernetes Kube Proxy
Documentation=https://github.com/kubernetes/kubernetes

[Service]
ExecStart=/usr/local/bin/kube-proxy \\
  --config=/var/lib/kube-proxy/kube-proxy-config.yaml
Restart=on-failure
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF

    {
      sudo systemctl daemon-reload
      sudo systemctl enable kubelet kube-proxy
      sudo systemctl start kubelet kube-proxy
    }

HERE
done
