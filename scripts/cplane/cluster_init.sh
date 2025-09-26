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
# 🚜 Image pull
# 🛠 Tools / Install
# 🔍 Get Info or Data or Config
# ✅ Good Result
# ❌ Bad Result
# ⬆ Up Arrow
# ⬇ Down Arrow
# ❓ Question / Unknown
# 🤷 Something missing
# 🔥 Creating something
# 👍 Startup
# ⏳ Waiting
# 🔄 Restarting
#

# Strip off errant 'localhost-y' reference that get created via vagrant
API_SERVER_IP=$(echo $(hostname -i | sed -E 's/127\.0\.[0-9]+\.[0-9]+//g'))
POD_BASE_CIDR=10.244.0.0 # Base address for pods

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
        timeout=60 # 1 minute = 60 seconds
    else
        timeout=1
    fi
    interval=10
    elapsed=0

    kube_services="kube-apiserver kube-controller-manager kube-scheduler kube-proxy etcd"

    # Find max svc name length (purely aesthetic)
    maxlen=0
    for kubsvc in $(echo ${kube_services}); do
        [ ${#kubsvc} -gt ${maxlen} ] && maxlen=${#kubsvc}
    done
    maxlen=$((maxlen + 2))

    while [ ${elapsed} -lt ${timeout} ]; do
        echo -n "🔍 Verify Kubernetes Services run state is '${state_check}'"
        if [ ${elapsed} -gt 0 ]; then
            echo " (trying for $((timeout - elapsed)) more seconds)"
        else
            echo ""
        fi

        # Clear up/down State Markers
        ksvcup=""
        ksvcdown=""

        # Check state of each service
        for kubsvc in $(echo ${kube_services}); do
            SVC_STATE=$(sudo crictl --runtime-endpoint ${D_SOC} ps -o json --name "${kubsvc}" 2>/dev/null | jq -r ".containers[] | select(.metadata.name == \"${kubsvc}\") | .state")

            # State Icons (actual vs compare)
            if [ "${SVC_STATE}" == "CONTAINER_RUNNING" ]; then
                ksvcup=y
                state_str="up"
                state_icon=$([ "${state_check}" == "up" ] && echo "⬆ ✅" || echo "⬆ ❌" )
            elif [ "${SVC_STATE}" == "" ]; then
                ksvcdown=y
                state_str="down"
                state_icon=$([ "${state_check}" == "down" ] && echo "⬇ ✅" || echo "⬇ ❌")
            else
                ksvcdown=y
                state_str="down / uncertain (state: '${SVC_STATE}')"
                state_icon="❓ ❌"
            fi
        printf "  %s Service %-*s: %s\n" "${state_icon}" "${maxlen}" "'${kubsvc}'" "${state_str}"
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
        elapsed=$((elapsed + interval))
        if [ "${exit_state}" == "0" ] ; then
            break
        elif [ ${elapsed} -lt ${timeout} ]; then
            echo "⏳ Retry - ${interval} second delay"
            sleep ${interval}
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
    sudo kubeadm init --pod-network-cidr=${POD_BASE_CIDR}/16 --apiserver-advertise-address=${API_SERVER_IP}
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
# NOTE: Weave Project was Shuttered in June 2024 and no longer supported
function install_weave_cni {
    echo "🚜  Install Weave CNI Service"
    kubectl apply -f https://github.com/weaveworks/weave/releases/download/v2.8.1/weave-daemonset-k8s.yaml --validate=false

    # Verify that CNI service is running
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
        elapsed=$((elapsed + interval))
        if [ ${weave_count} -gt 0 ]; then
            break
        elif [ ${elapsed} -lt ${timeout} ]; then
            sleep ${interval}
        fi
    done

    if [ ${weave_count} -gt 0 ]; then
        echo "✅ Weave CNI Service is running"
    else
        echo "❌ Timed out during check - Weave CNI service is NOT running"
        exit 1
    fi
}


function install_flannel_cni {
    echo "🚜  Install Flannel CNI Service"

    # The Prepackaged Flannel CNI is hard coded to use CIDR of 10.244.0.0/16
    if ! [ "${POD_BASE_CIDR}" == "10.244.0.0" ]; then
        echo "❌ For Flannel CNI via 'kubectl apply', var 'POD_BASE_CIDR' must be '10.244.0.0'"
        echo "   (POD_BASE_CIDR is currently defined as '${POD_BASE_CIDR}')"
        echo ""
        exit 1
    fi

    # Check for Kernel module 'br_netfilter' - Bridge Network Filter
    if [ "$(lsmod | grep br_netfilter)" == "" ]; then
        echo "⚙️  Enable Kernel module 'br_netfilter' - Bridge Network Filter"
        sudo modprobe br_netfilter
    fi

    # Install Flannel Service
    kubectl apply -f https://raw.githubusercontent.com/flannel-io/flannel/master/Documentation/kube-flannel.yml --validate=false

    # Restart the kubelet
    sudo service kubelet restart

    # Verify that CNI service is running
    timeout=60 # 1 minute = 60 seconds
    interval=10 # check every 10 seconds
    elapsed=0
    while [ ${elapsed} -lt ${timeout} ]; do
        echo -n "🔍 Verify Flannel Service running"
        if [ ${elapsed} -gt 0 ]; then
            echo " (trying for $((timeout - elapsed)) more seconds)"
        else
            echo ""
        fi

        # If Flannel is running correctly then it will report back the pods list
        flannel_state=$(kubectl get pods -n kube-flannel -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name | startswith("kube-flannel-")) | .status.phase')

        elapsed=$((elapsed + interval))
        if [ ${flannel_state} == "Running" ]; then
            break
        elif [ ${elapsed} -lt ${timeout} ]; then
            sleep ${interval}
        fi
    done

    if [ ${flannel_state} == "Running" ]; then
        echo "✅ Flannel CNI Service is running"
    else
        echo "❌ Timed out during check - Flannel CNI service is NOT running"
        exit 1
    fi
}


# Install the Rancher LocalPath StorageClass implementation
function install_localpath_storageclass {
    echo "🚜  Install Rancher 'local-path' StorageClass"
    kubectl apply -f https://raw.githubusercontent.com/rancher/local-path-provisioner/v0.0.32/deploy/local-path-storage.yaml --validate=false
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
#install_weave_cni
install_flannel_cni
install_localpath_storageclass
