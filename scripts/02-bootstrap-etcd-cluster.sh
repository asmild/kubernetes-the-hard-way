#!/bin/bash

ETCD_VERSION=3.5.4
# Run on both masters

for instance in master-1 master-2; do
  echo "[Step 1: ${instance}] Download and Install the etcd Binaries"
  ssh -t ${instance} << HERE
    wget -q --show-progress --https-only --timestamping \
       "https://github.com/coreos/etcd/releases/download/v${ETCD_VERSION}/etcd-v${ETCD_VERSION}-linux-amd64.tar.gz"
    {
	tar -xvf etcd-v${ETCD_VERSION}-linux-amd64.tar.gz
	sudo mv etcd-v${ETCD_VERSION}-linux-amd64/etcd* /usr/local/bin/
    }
    echo "[Step 2: ${instance}] Configure the etcd Server"

    sudo mkdir -p /etc/etcd /var/lib/etcd
    sudo cp ca.crt etcd-server.key etcd-server.crt /etc/etcd/

    INTERNAL_IP=\$(ip addr show enp0s8 | grep "inet " | awk '{print \$2}' | cut -d / -f 1)
    ETCD_NAME=\$(hostname -s)
    cat << EOF | sudo tee /etc/systemd/system/etcd.service
	[Unit]
	Description=etcd
	Documentation=https://github.com/coreos

	[Service]
	ExecStart=/usr/local/bin/etcd \\
	  --name \${ETCD_NAME} \\
	  --cert-file=/etc/etcd/etcd-server.crt \\
	  --key-file=/etc/etcd/etcd-server.key \\
	  --peer-cert-file=/etc/etcd/etcd-server.crt \\
	  --peer-key-file=/etc/etcd/etcd-server.key \\
	  --trusted-ca-file=/etc/etcd/ca.crt \\
	  --peer-trusted-ca-file=/etc/etcd/ca.crt \\
	  --peer-client-cert-auth \\
	  --client-cert-auth \\
	  --initial-advertise-peer-urls https://\${INTERNAL_IP}:2380 \\
	  --listen-peer-urls https://\${INTERNAL_IP}:2380 \\
	  --listen-client-urls https://\${INTERNAL_IP}:2379,https://127.0.0.1:2379 \\
	  --advertise-client-urls https://\${INTERNAL_IP}:2379 \\
	  --initial-cluster-token etcd-cluster-0 \\
	  --initial-cluster master-1=https://192.168.5.11:2380,master-2=https://192.168.5.12:2380 \\
	  --initial-cluster-state new \\
	  --data-dir=/var/lib/etcd
	Restart=on-failure
	RestartSec=5

	[Install]
	WantedBy=multi-user.target
EOF
    sudo systemctl daemon-reload
    sudo systemctl enable etcd
    sudo systemctl start etcd
HERE
done

ssh master-1 << HERE
sudo ETCDCTL_API=3 etcdctl member list \
  --endpoints=https://127.0.0.1:2379 \
  --cacert=/etc/etcd/ca.crt \
  --cert=/etc/etcd/etcd-server.crt \
  --key=/etc/etcd/etcd-server.key
HERE
