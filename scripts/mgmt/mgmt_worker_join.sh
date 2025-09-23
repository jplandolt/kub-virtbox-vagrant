#!/usr/bin/env bash

cplane_join_cmd=""
cplane_kube_cfg=kube_cfg.txt

function welcome_msg {
    echo ""
    echo "⚙️  Joining Worker Nodes to the Cluster"
}

# Is the Control Plane Ready to accept worker node joins?
function controlplane_sanity {
    echo "🔍 Checking state of Control Plane"
    cplane_status=$(vagrant status --machine-readable cplane | grep ',state,' | cut -d',' -f 4)

    echo "✨ Status of Control Plane '${cplane_status}'"
    if ! [ "${cplane_status,,}" == "running" ] ; then
        echo "🤷 Control Plane Node is not running or able to accept worker node joins"
        exit 1
    else
        echo "⚙️  Getting worker 'join' command from the Control Plane"
        cplane_join_cmd=$(vagrant ssh cplane -c "kubeadm token create --print-join-command" | tr -d '\r')
        cplane_join_cmd=$(echo "${cplane_join_cmd}" | sed 's/[ ]$//')

        if [ "${cplane_join_cmd}" == "" ]; then
            echo "❌ Failed to retrieve the Control Plane join command"
            exit 1
        fi

        echo "⚙️  Getting kube config file from the Control Plane"
        rm -f ${cplane_kube_cfg}
        vagrant ssh cplane -c "cat .kube/config" > ${cplane_kube_cfg}
    fi
}


function worker_join {
    echo "⚙️  Joining Worker Nodes:"
    echo "-----------------------------------"

    echo "🔍 Get List of Worker nodes currently attached to the control plane"
    worker_nodes_attached=$(vagrant ssh cplane -c "kubectl get nodes" | grep -v cplane | grep -v ROLES | cut -d' ' -f 1)
    echo ""

    for wnode in ${worker_nodes_attached}; do
        if [ "${attached_nodes}" == "" ] ; then
            attached_nodes="|"
        fi
        attached_nodes="${attached_nodes}${wnode}|"
    done

    # Evaluate each Worker Node
    for wnode in $(ruby Vagrantfile list_names worker); do
        echo "⚙️  Joining Worker node '${wnode}' to the Cluster"
        echo "-----------------------------------"
        node_status=$(vagrant status --machine-readable ${wnode} | grep ',state,' | cut -d',' -f 4)
        echo "✨ Status of VM '${wnode}' is '${node_status}'"

        if ! [ "${node_status,,}" == "running" ] ; then
            echo "🤷 Worker VM '${wnode}' is not running or able to join cluster"
        else
            echo "✅ Worker VM '${wnode}' is running"
            echo "🔍 Checking to see if node '${wnode}' is free to join the cluster"

            wcheck=$(echo ${attached_nodes} | grep "|${wnode}|")
            if ! [ "${wcheck}" == "" ] ; then
                echo "  '${wnode}' is already attached to the control plane"
            else
                echo "  '${wnode}' can attach to the control plane - attaching"
#                vagrant ssh ${wnode} -c "sudo ${cplane_join_cmd}"
#                vagrant ssh ${wnode} -c "mkdir -p .kube"
#                vagrant upload ${cplane_kube_cfg} .kube/config ${wnode}
            fi

            echo "🔍 Verifying node '${wnode}' has joined the cluster"
            node_join_state=$(vagrant ssh ${wnode} -c "kubectl get nodes ${wnode}" | grep -v "VERSION" | tr -d '\r')

            # node_join_state will have the node name and status if found
            # and a "(NotFound) error if missing"
            if ! [[ "${node_join_state}" =~ ".*NotFound.*" ]]; then
                echo "✅ Worker VM '${wnode}' is attached to the cluster"

                echo "⚙️  Applying node label 'worker' to node '${wnode}'"
                label_result=$(vagrant ssh ${wnode} -c "kubectl label nodes ${wnode} node-role.kubernetes.io/worker=worker" | tr -d '\r')
            else
                echo "🤷 Worker VM '${wnode}' is NOT attached to the cluster"
#                exit 1
            fi
        fi
        echo "-----------------------------------"
    done


    # Clean up file after work - shouldn't leave this floating around
    rm -f ${cplane_kube_cfg}
    echo ""
}

function finish_up {
    rm -f ${cplane_kube_cfg}
}

#
# Main Script Execution
#
welcome_msg
controlplane_sanity
worker_join
finish_up
