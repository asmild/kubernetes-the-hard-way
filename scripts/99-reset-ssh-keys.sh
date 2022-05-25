#!/bin/bash

for instance in 192.168.5.11 192.168.5.12 192.168.5.21 192.168.5.22 192.168.5.30; do
  echo "checking:" ${instance}
  ssh-keygen -f "/home/asmild/.ssh/known_hosts" -R "${instance}"
done

for instance in master-1 master-2 worker-1 worker-2 loadbalancer; do
  echo "Checking:" ${instance}
  ssh-keygen -f "/home/asmild/.ssh/known_hosts" -R "${instance}"
done
