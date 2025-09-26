#!/usr/bin/env bash

#
# Shows the state of the Kubernetes Cluster
# Shows the list of current pods (if any)
#

# Get the IP of the Control Plane
CPLANE_IP=$(ruby Vagrantfile list_ips cplane)

function cluster_state {
    if [ "$(wget -qL -O- --no-check-certificate https://${CPLANE_IP}:6443/readyz 2>/dev/null)" == "ok" ]; then
        echo "Kube Control Plane UP"
        echo ""
        kubectl get nodes

        podlist=$(kubectl get pods 2>/dev/null)
        if ! [ "${podlist}" == "" ]; then
            echo ""
            kubectl get pods 2>/dev/null
        fi
    else
        echo "Kube Control Plane DOWN"
    fi
}

#
# Execution loop
# the 'watch' parameter causes the script to "re-execute"
# but puts in a watch loop with an X second delay
#
if [ "${1}" == "watch" ] ; then
	watch -n 5 ${0}
else
    # This script calls itself again, in "single use" mode
	cluster_state
fi
