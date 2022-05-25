#!/bin/bash
CERTIFICATES_FOLDER=certs
EXPIRE_IN=10000

mkdir certs
echo "[Step 1] Certificate Authority"

# Create private key for CA
openssl genrsa -out certs/ca.key 2048

# Comment line starting with RANDFILE in /etc/ssl/openssl.cnf definition to avoid permission issues
sudo sed -i '0,/RANDFILE/{s/RANDFILE/\#&/}' /etc/ssl/openssl.cnf

# Create CSR using the private key
openssl req -new -key certs/ca.key -subj "/CN=KUBERNETES-CA" -out certs/ca.csr

# Self sign the csr using its own private key
openssl x509 -req -in certs/ca.csr -signkey certs/ca.key -CAcreateserial  -out certs/ca.crt -days ${EXPIRE_IN}


echo "[Step 2] Client and Server Certificates"
echo "[      a:] The Admin Client Certificate"

# Generate private key for admin user
openssl genrsa -out certs/admin.key 2048

# Generate CSR for admin user. Note the OU.
openssl req -new -key certs/admin.key -subj "/CN=admin/O=system:masters" -out certs/admin.csr

# Sign certificate for admin user using CA servers private key
openssl x509 -req -in certs/admin.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial  -out certs/admin.crt -days ${EXPIRE_IN}

echo "[      b:] The Controller Manager Client Certificate"
openssl genrsa -out certs/kube-controller-manager.key 2048
openssl req -new -key certs/kube-controller-manager.key -subj "/CN=system:kube-controller-manager" -out certs/kube-controller-manager.csr
openssl x509 -req -in certs/kube-controller-manager.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial -out certs/kube-controller-manager.crt -days ${EXPIRE_IN}

echo "[      c:] The Kube Proxy Client Certificate"
openssl genrsa -out certs/kube-proxy.key 2048
openssl req -new -key certs/kube-proxy.key -subj "/CN=system:kube-proxy" -out certs/kube-proxy.csr
openssl x509 -req -in certs/kube-proxy.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial  -out certs/kube-proxy.crt -days ${EXPIRE_IN}

echo "[      d:] The Kube Proxy Client Certificate"
openssl genrsa -out ${CERTIFICATES_FOLDER}/kube-scheduler.key 2048
openssl req -new -key ${CERTIFICATES_FOLDER}/kube-scheduler.key -subj "/CN=system:kube-scheduler" -out ${CERTIFICATES_FOLDER}/kube-scheduler.csr
openssl x509 -req -in ${CERTIFICATES_FOLDER}/kube-scheduler.csr -CA ${CERTIFICATES_FOLDER}/ca.crt -CAkey ${CERTIFICATES_FOLDER}/ca.key -CAcreateserial  -out ${CERTIFICATES_FOLDER}/kube-scheduler.crt -days ${EXPIRE_IN}

echo "[      e:] The Kubernetes API Server Certificate"
cat > certs/openssl.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
DNS.1 = kubernetes
DNS.2 = kubernetes.default
DNS.3 = kubernetes.default.svc
DNS.4 = kubernetes.default.svc.cluster.local
IP.1 = 10.96.0.1
IP.2 = 192.168.5.11
IP.3 = 192.168.5.12
IP.4 = 192.168.5.30
IP.5 = 127.0.0.1
EOF

openssl genrsa -out certs/kube-apiserver.key 2048
openssl req -new -key certs/kube-apiserver.key -subj "/CN=kube-apiserver" -out certs/kube-apiserver.csr -config certs/openssl.cnf
openssl x509 -req -in certs/kube-apiserver.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial  -out certs/kube-apiserver.crt -extensions v3_req -extfile certs/openssl.cnf -days ${EXPIRE_IN}

echo "[      f:] The ETCD Server Certificate"
cat > certs/openssl-etcd.cnf <<EOF
[req]
req_extensions = v3_req
distinguished_name = req_distinguished_name
[req_distinguished_name]
[ v3_req ]
basicConstraints = CA:FALSE
keyUsage = nonRepudiation, digitalSignature, keyEncipherment
subjectAltName = @alt_names
[alt_names]
IP.1 = 192.168.5.11
IP.2 = 192.168.5.12
IP.3 = 127.0.0.1
EOF

openssl genrsa -out certs/etcd-server.key 2048
openssl req -new -key certs/etcd-server.key -subj "/CN=etcd-server" -out certs/etcd-server.csr -config certs/openssl-etcd.cnf
openssl x509 -req -in certs/etcd-server.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial  -out certs/etcd-server.crt -extensions v3_req -extfile certs/openssl-etcd.cnf -days ${EXPIRE_IN}

echo "[      d:] The Service Account Key Pair"
openssl genrsa -out certs/service-account.key 2048
openssl req -new -key certs/service-account.key -subj "/CN=service-accounts" -out certs/service-account.csr
openssl x509 -req -in certs/service-account.csr -CA certs/ca.crt -CAkey certs/ca.key -CAcreateserial  -out certs/service-account.crt -days ${EXPIRE_IN}


echo "[Step 3] Distribute the Certificates"
for instance in master-1 master-2; do
  scp \
    ${CERTIFICATES_FOLDER}/ca.crt \
    ${CERTIFICATES_FOLDER}/ca.key \
    ${CERTIFICATES_FOLDER}/kube-apiserver.key \
    ${CERTIFICATES_FOLDER}/kube-apiserver.crt \
    ${CERTIFICATES_FOLDER}/service-account.key \
    ${CERTIFICATES_FOLDER}/service-account.crt \
    ${CERTIFICATES_FOLDER}/etcd-server.key \
    ${CERTIFICATES_FOLDER}/etcd-server.crt \
    ${instance}:~/
done

