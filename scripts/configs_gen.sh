#!/bin/bash
# proxy
LOADBALANCER_ADDRESS=192.168.5.30

echo " ---- Generating kube-proxy config"
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=certs/ca.crt \
    --embed-certs=true \
    --server=https://${LOADBALANCER_ADDRESS}:6443 \
    --kubeconfig=kubeconfigs/kube-proxy.kubeconfig

  kubectl config set-credentials system:kube-proxy \
    --client-certificate=certs/kube-proxy.crt \
    --client-key=certs/kube-proxy.key \
    --embed-certs=true \
    --kubeconfig=kubeconfigs/kube-proxy.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-proxy \
    --kubeconfig=kubeconfigs/kube-proxy.kubeconfig

  kubectl config use-context default --kubeconfig=kubeconfigs/kube-proxy.kubeconfig
}


echo " ---- Generating controller-manager config"
# controller-manager
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=certs/ca.crt \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kubeconfigs/kube-controller-manager.kubeconfig

  kubectl config set-credentials system:kube-controller-manager \
    --client-certificate=certs/kube-controller-manager.crt \
    --client-key=certs/kube-controller-manager.key \
    --embed-certs=true \
    --kubeconfig=kubeconfigs/kube-controller-manager.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-controller-manager \
    --kubeconfig=kubeconfigs/kube-controller-manager.kubeconfig

  kubectl config use-context default --kubeconfig=kubeconfigs/kube-controller-manager.kubeconfig
}


echo " ---- generating scheduler config"
# scheduler
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=certs/ca.crt \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kubeconfigs/kube-scheduler.kubeconfig

  kubectl config set-credentials system:kube-scheduler \
    --client-certificate=certs/kube-scheduler.crt \
    --client-key=certs/kube-scheduler.key \
    --embed-certs=true \
    --kubeconfig=kubeconfigs/kube-scheduler.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=system:kube-scheduler \
    --kubeconfig=kubeconfigs/kube-scheduler.kubeconfig

  kubectl config use-context default --kubeconfig=kubeconfigs/kube-scheduler.kubeconfig
}

echo " ---- generating admin config"
# admin
{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=certs/ca.crt \
    --embed-certs=true \
    --server=https://127.0.0.1:6443 \
    --kubeconfig=kubeconfigs/admin.kubeconfig

  kubectl config set-credentials admin \
    --client-certificate=certs/admin.crt \
    --client-key=certs/admin.key \
    --embed-certs=true \
    --kubeconfig=kubeconfigs/admin.kubeconfig

  kubectl config set-context default \
    --cluster=kubernetes-the-hard-way \
    --user=admin \
    --kubeconfig=kubeconfigs/admin.kubeconfig

  kubectl config use-context default --kubeconfig=kubeconfigs/admin.kubeconfig
}


echo " ---- copying to worker nodes"
# distribution of config
for instance in worker-1 worker-2; do
  scp kubeconfigs/kube-proxy.kubeconfig vagrant@${instance}:~/
done

echo " ---- copying to mater nodes"
for instance in master-1 master-2; do
  scp kubeconfigs/admin.kubeconfig kubeconfigs/kube-controller-manager.kubeconfig kubeconfigs/kube-scheduler.kubeconfig vagrant@${instance}:~/
done


echo " ---- some encryption stuff"
#The Encryption Key
ENCRYPTION_KEY=$(head -c 32 /dev/urandom | base64)

cat > kubeconfigs/encryption-config.yaml <<EOF
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

echo " ---- copying encryption stuff to masters"

for instance in master-1 master-2; do
  scp kubeconfigs/encryption-config.yaml vagrant@${instance}:~/
done

for instance in master-1 master-2; do
  ssh vagrant@${instance} 'sudo mkdir -p /var/lib/kubernetes && sudo mv encryption-config.yaml /var/lib/kubernetes/'
done

