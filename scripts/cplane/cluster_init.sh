#!/bin/bash
#
# Script to Initialize the Control Plane
#
# Grab the kubernetes service images
# init the service, specifing the base CIDR
# copy the kube config to the user directory
# install the WEAVE CNI service
#
# The IP Address for the API_SERVER is the host ip address for the machine
#
# Unicode Character icons (https://www.compart.com/en/unicode)
#
# 😄 Generic Info
# ☸️ Kubernetes
# ✨ Perform Magic
# ⚙️ Setting something
# 🛠 Tools / Install
# 🔍 Get Info or Data or Config
# ✅ Good Result
# ❌ Bad Result
# 🚜 Image pull
# 🤷 Something missing
# 🔥 Creating something
# 👍 Startup
# ⏳ Waiting
# 🔄 Restarting
#

# Strip off errant 'localhost-y' reference that get created via vagrant
API_SERVER_IP=$(echo $(hostname -i | sed -E 's/127\.0\.[0-9]+\.[0-9]+//g'))
POD_BASE_CIDR=10.201.0.0 # Base address for pods

function welcome_msg {
    echo "Kubernetes Control Plane / Cluster Init"
    echo ""
    echo "POD_BASE_CIDR: '${POD_BASE_CIDR}'"
    echo "API_SERVER_IP: '${API_SERVER_IP}'"
    echo ""
}

# Quick check to see if Kubernetes utilities are install
function kube_sanity_check {
    # Are Kubernetes tools installed?
    echo "🔍 Check for kubernetes tools on the machine"

    kube_tools="kubelet kubeadm kubectl"
    for ktool in $(echo ${kube_tools}); do
        if ! command -v ${ktool} >/dev/null 2>&1; then
            echo "🤷 utility '${ktool}' not found"
            ktoolmissing=y
        fi
    done

    if [ "${ktoolmissing}" == "y" ] ; then
        echo "❌ one ore more kubernetes utilities missing; install before continuing"
        exit 1
    fi
}


# Verify that the api server is up and running ?
# or all are down
#
# Param 1 - "up" or "down"
# Param 2 - optional - "retry" for a retry loop
#
function verify_controlplane_state {
    D_SOC=unix:///var/run/containerd/containerd.sock

    state_check="${1,,}"
    if ! [[ ${state_check} = @(up|down) ]]; then
       echo "❌ Invalid parameter must be 'up' or 'down'"
       exit 1
    fi

    # Option to allow for delayed retries
    # to allow for services to start up
    if [ "${2,,}" == "retry" ]; then
        retries=5
    else
        retries=0
    fi
    interval=10
    kube_services="kube-apiserver kube-controller-manager kube-scheduler kube-proxy etcd"

    # Loop to handle retries (from 0 to 2)
    # 0 retries means that this check happens once with no delay
    while [ ${retries} -ge 0 ]; do
        echo "🔍 Verify Kubernetes Services run state is '${state_check}'"

        # Clear up/down State Markers
        ksvcup=""
        ksvcdown=""

        # Check state of each service
        for kubsvc in $(echo ${kube_services}); do
            SVC_STATE=$(sudo crictl --runtime-endpoint ${D_SOC} ps -o json --name "${kubsvc}" 2>/dev/null | jq -r ".containers[] | select(.metadata.name == \"${kubsvc}\") | .state")

            if   [ "${SVC_STATE}" == "CONTAINER_RUNNING" ]; then
                echo "  🔍 Service '${kubsvc}' is up and running"
                ksvcup=y
            elif [ "${SVC_STATE}" == "" ]; then
                echo "  🔍 Service '${kubsvc}' is down"
                ksvcdown=y
            else
                echo "  🔍 Service '${kubsvc}' is uncertain - state: '${SVC_STATE}'"
                ksvcdown=y
            fi
        done

        state_check="${1,,}"
        if [ "${ksvcup}" == "y" ] && [ "${ksvcdown}" == "y" ] ; then
            echo "❌ Uncertain state - some Kubernetes services are Up while others are Down"
            exit_state=1
        elif [ "${state_check}" == "up" ] && [ "${ksvcdown}" == "y" ] ; then
            echo "❌ Expected state is UP but one or more kubernetes services are not running"
            exit_state=1
        elif [ "${state_check}" == "down" ] && [ "${ksvcup}" == "y" ] ; then
            echo "❌ Expected state is DOWN but one or more kubernetes services are running"
            exit_state=1
        else
            echo "✅ Kubernetes Services in expected state: '${state_check}'"
            exit_state=0
            retries=0
        fi

        # If there is a retry to be had, notify, delay, and repeat
        retries=$((retries - 1))
        if [ ${retries} -ge 0 ]; then
            echo "⏳ Retry requested after ${interval} second delay"
                sleep ${interval}
            echo ""
        fi
    done

    # didn't work; exit out
    if [ "${exit_state}" == "1" ] ; then
        exit 1
    fi
}


function controlplane_init {
    # Pull down the Kubernetes images for Control Plane Initialization
    echo "🚜  Pulling Kubernetes execution Images"
    sudo kubeadm config images pull

    # Spin up the Control Plane Node (and cluster)
    echo "🔄  Initializing Cluster"
    sudo kubeadm init --pod-network-cidr=10.201.0.0/16 --apiserver-advertise-address=192.168.63.11
}


# Copy the k8s admin.conf into the user directory for subsequent use
function kubeconf_copy {
    if [ -f /etc/kubernetes/admin.conf ] ; then
        echo "⚙️  Create local '.kube/config'"
        mkdir -p ${HOME}/.kube
        sudo cp -f /etc/kubernetes/admin.conf ${HOME}/.kube/config
        sudo chown $(id -u):$(id -g) ${HOME}/.kube/config
    fi
}


# Install the Weave CNI (Container Network Interface)
function weave_install {
    echo "🚜  Install Weave CNI Service"
    kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml --validate=false

    # Verify that weave is running
    timeout=60 # 2 minutes = 120 seconds
    interval=10 # check every 10 seconds
    elapsed=0
    while [ ${elapsed} -lt ${timeout} ]; do
        echo -n "🔍 Verify Weave Service running"
        if [ ${elapsed} -gt 0 ]; then
            echo " (trying for $((timeout - elapsed)) more seconds)"
        else
            echo ""
        fi

        # If Weave is running correctly then it will report back the pods list
        weave_count=$(kubectl get pods -n kube-system -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | startswith("weave-net-")) | .metadata.name' | wc -l)
        if [ ${weave_count} -gt 0 ]; then
            break
        else
            sleep ${interval}
            elapsed=$((elapsed + interval))
        fi
    done

    if [ ${weave_count} -gt 0 ]; then
        echo "✅ Weave CNI Service is running"
    else
        echo "❌ Timed out during check - Weave CNI service is NOT running"
        exit 1
    fi
}

#
# Main Execution Loop
#
welcome_msg
kube_sanity_check
verify_controlplane_state down
controlplane_init
kubeconf_copy
verify_controlplane_state up retry
weave_install
