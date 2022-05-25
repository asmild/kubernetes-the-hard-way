#!/bin/bash

GUEST_ADDITION_VERSION=6.1.34
GUEST_ADDITION_ISO=VBoxGuestAdditions_${GUEST_ADDITION_VERSION}.iso
GUEST_ADDITION_MOUNT=/media/VBoxGuestAdditions

for instance in master-1 master-2 worker-1 worker-2 loadbalancer; do
 ssh -t ${instance} << HERE
apt-get install linux-headers-$(uname -r) build-essential dkms

wget http://download.virtualbox.org/virtualbox/${GUEST_ADDITION_VERSION}/${GUEST_ADDITION_ISO}
mkdir -p ${GUEST_ADDITION_MOUNT}
mount -o loop,ro ${GUEST_ADDITION_ISO} ${GUEST_ADDITION_MOUNT}
sh ${GUEST_ADDITION_MOUNT}/VBoxLinuxAdditions.run
rm ${GUEST_ADDITION_ISO}
umount ${GUEST_ADDITION_MOUNT}
rmdir ${GUEST_ADDITION_MOUNT}
HERE
done