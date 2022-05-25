#!/bin/bash
LOADBALANCER_ADDRESS=192.168.5.30
CONFIG_FOLDER=kubeconfigs
CERTIFICATES_FOLDER=certs
mkdir ${CONFIG_FOLDER}

echo "The kube-proxy Kubernetes Configuration File"

{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=${CERTIFICATES_FOLDER}/ca.crt \
    --embed-certs=true \
    --server=https://${LOADBALANCER_ADDRESS}:6443 \
    --kubeconfig=${CONFIG_FOLDER}/kube-proxy.kubeconfig

  kubectl config set-credentials system:kube-proxy \
    --client-certificate=${CERTIFICATES_FOLDER}/kube-proxy.crt \
    --client-key=${CERTIFICATES_FOLDER}/kube-proxy.key \
    --embed-certs=true \
    --kubeconfig=${CONFIG_FOLDER}/kube-proxy.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-proxy \
    --kubeconfig=${CONFIG_FOLDER}/kube-proxy.kubeconfig

  kubectl config use-context default --kubeconfig=${CONFIG_FOLDER}/kube-proxy.kubeconfig
}

echo "The kube-controller-manager Kubernetes Configuration File"
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=${CERTIFICATES_FOLDER}/ca.crt \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=${CONFIG_FOLDER}/kube-controller-manager.kubeconfig

  kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=${CERTIFICATES_FOLDER}/kube-controller-manager.crt \
    --client-key=${CERTIFICATES_FOLDER}/kube-controller-manager.key \
    --embed-certs=true \
    --kubeconfig=${CONFIG_FOLDER}/kube-controller-manager.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-controller-manager \
    --kubeconfig=${CONFIG_FOLDER}/kube-controller-manager.kubeconfig

  kubectl config use-context default --kubeconfig=${CONFIG_FOLDER}/kube-controller-manager.kubeconfig
}

echo "The kube-scheduler Kubernetes Configuration File"
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=${CERTIFICATES_FOLDER}/ca.crt \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=${CONFIG_FOLDER}/kube-scheduler.kubeconfig

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=${CERTIFICATES_FOLDER}/kube-scheduler.crt \
    --client-key=${CERTIFICATES_FOLDER}/kube-scheduler.key \
    --embed-certs=true \
    --kubeconfig=${CONFIG_FOLDER}/kube-scheduler.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-scheduler \
    --kubeconfig=${CONFIG_FOLDER}/kube-scheduler.kubeconfig

  kubectl config use-context default --kubeconfig=${CONFIG_FOLDER}/kube-scheduler.kubeconfig
}

echo "The admin Kubernetes Configuration File"
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=${CERTIFICATES_FOLDER}/ca.crt \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=${CONFIG_FOLDER}/admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=${CERTIFICATES_FOLDER}/admin.crt \
    --client-key=${CERTIFICATES_FOLDER}/admin.key \
    --embed-certs=true \
    --kubeconfig=${CONFIG_FOLDER}/admin.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=admin \
    --kubeconfig=${CONFIG_FOLDER}/admin.kubeconfig

  kubectl config use-context default --kubeconfig=${CONFIG_FOLDER}/admin.kubeconfig
}

echo "Distribute the Kubernetes Configuration Files"
for instance in worker-1 worker-2; do
  scp ${CONFIG_FOLDER}/kube-proxy.kubeconfig ${instance}:~/
done


for instance in master-1 master-2; do
  scp ${CONFIG_FOLDER}/admin.kubeconfig ${CONFIG_FOLDER}/kube-controller-manager.kubeconfig ${CONFIG_FOLDER}/kube-scheduler.kubeconfig ${instance}:~/
done


echo "The Encryption Key"
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

echo "The Encryption Config File"
cat > ${CONFIG_FOLDER}/encryption-config.yaml <<EOF
kind: EncryptionConfig
apiVersion: v1
resources:
  - resources:
      - secrets
    providers:
      - aescbc:
          keys:
            - name: key1
              secret: ${ENCRYPTION_KEY}
      - identity: {}
EOF

for instance in master-1 master-2; do
  scp ${CONFIG_FOLDER}/encryption-config.yaml ${instance}:~/
done

for instance in master-1 master-2; do
  ssh ${instance} << EOF
    sudo mkdir -p /var/lib/kubernetes/
    sudo mv encryption-config.yaml /var/lib/kubernetes/
EOF
done
