#!/bin/bash
LOADBALANCER_ADDRESS=192.168.5.30
CERTIFICATES_FOLDER=certs

{
  kubectl config set-cluster kubernetes-the-hard-way \
    --certificate-authority=${CERTIFICATES_FOLDER}/ca.crt \
    --embed-certs=true \
    --server=https://${LOADBALANCER_ADDRESS}:6443

  kubectl config set-credentials admin \
    --client-certificate=${CERTIFICATES_FOLDER}/admin.crt \
    --client-key=${CERTIFICATES_FOLDER}/admin.key

  kubectl config set-context kubernetes-the-hard-way \
    --cluster=kubernetes-the-hard-way \
    --user=admin

  kubectl config use-context kubernetes-the-hard-way
}