#!/usr/bin/env bash

# To Watch this in a loop:
#
# watch -n 5 ./mgmt_kube_state.sh
#

CPLANE_IP=$(ruby Vagrantfile list_ips cplane)
if [ "$(wget -qL -O- --no-check-certificate https://${CPLANE_IP}:6443/readyz 2>/dev/null)" == "ok" ]; then
    echo "Kube Control Plane UP"
    echo ""
    kubectl get nodes
else
    echo "Kube Control Plane DOWN"
fi

