#!/usr/bin/env bash

cplane_join_cmd=""
cplane_kube_cfg=kube_cfg.txt

function welcome_msg() {
    echo ""
    echo "⚙️  Copying Kubernetes Config from the Control Plane"
}

# Is the Control Plane Ready to accept worker node joins?
function controlplane_sanity() {
    echo "🔍 Checking state of Control Plane"
    cplane_status=$(vagrant status --machine-readable cplane | grep ',state,' | cut -d',' -f 4)

    echo "✨ Status of Control Plane '${cplane_status}'"
    if ! [ "${cplane_status,,}" == "running" ] ; then
        echo "🤷 Control Plane Node is not running"
        exit 1
   fi
}

function copy_kubcfg() {
    echo "⚙️  Getting kube config file from the Control Plane"
    rm -f ${cplane_kube_cfg}
    vagrant ssh cplane -c "sudo cat /etc/kubernetes/admin.conf" | sed $'s/\r$//' > ${cplane_kube_cfg}

    echo "⚙️  Move kube config file to \${HOME}/.kube/config"
    mkdir -p ${HOME}/.kube
    rm -rf ${HOME}/.kube/config
    mv ${cplane_kube_cfg} ${HOME}/.kube/config
}


function verify_kubcfg() {
    echo "🔍 Verify communication with the Control Plane"

    echo ""
    kubectl cluster-info
    retval=${?}
    echo ""

    if [ "${retval}" == "0" ] ; then
        echo "✅ Local communication with the Control Plane SUCCESS"
    else
        echo "❌ Local communication with the Control Plane FAILURE"
        exit 1
    fi
}


#
# Main Script Execution
#
welcome_msg
controlplane_sanity
copy_kubcfg
verify_kubcfg
