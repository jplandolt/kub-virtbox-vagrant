#!/usr/bin/env bash

function list_pods() {
    echo "All Pods:"
    echo "---------------------------"
    kubectl get pod --all-namespaces -o json 2>/dev/null | jq -r '.items[] | select(.metadata.name) | .metadata.name'
    echo ""
    echo "Pods with NodePort Service:"
    echo "---------------------------"
    for svc in $(kubectl get svc --all-namespaces -o json 2>/dev/null | jq -r '.items[] | select(.spec.type == "NodePort") | .spec.selector["k8s-app"]') ; do
        pod=$(kubectl get pod --all-namespaces -o json 2>/dev/null | jq -r --arg pod_sel "${svc}" '.items[] | select(.metadata.labels["k8s-app"] == $pod_sel) | .metadata.name')

        echo "Nodeport Svc: '${svc}', Pod: '${pod}'"
    done
    echo ""
}

function get_pod_ref() {
    ref_pod=${1}
    echo "getting access point for pod '${ref_pod}'"
    echo ""

    # Get pod json data (do it once here rather than multiple)
    json_data=$(kubectl get pod --all-namespaces -o json 2>/dev/null)

    # Host IP Address and the "app" label come from the Pod
    host_ip=$(echo ${json_data} | jq -r --arg pod_name "${ref_pod}" '.items[] | select(.metadata.name == $pod_name) | .status.hostIP')
    app_sel=$(echo ${json_data} | jq -r --arg pod_name "${ref_pod}" '.items[] | select(.metadata.name == $pod_name) | .metadata.labels["k8s-app"]')

    if [ "${host_ip}" == "" ] ; then
        echo "Pod '${ref_pod}' not found"
	exit 1
    else
        echo "ref_pod:   '${ref_pod}'"
        echo "host_ip:   '${host_ip}'"
        echo "app_sel:   '${app_sel}'"

        # Get svc json data (do it once here rather than multiple)
        json_data=$(kubectl get svc --all-namespaces -o json 2>/dev/null)

        # nodePort comes from the Service, where Svc.app.selector == Pod.label.app
        svc_sel=$(  echo ${json_data} | jq -r --arg app_name "${app_sel}" '.items[] | select(.spec.selector["k8s-app"] == $app_name) | .metadata.name')
        svc_type=$( echo ${json_data} | jq -r --arg app_name "${app_sel}" '.items[] | select(.spec.selector["k8s-app"] == $app_name) | .spec.type')
        node_port=$(echo ${json_data} | jq -r --arg app_name "${app_sel}" '.items[] | select(.spec.selector["k8s-app"] == $app_name) | .spec.ports[].nodePort')

        echo "svc_sel:   '${svc_sel}'"
        echo "svc_type:  '${svc_type}'"
        echo "node_port: '${node_port}'"

        if [ "${svc_type}" != "NodePort" ] ; then
            echo "Pod is not attached to a 'NodePort' Service"
            echo ""
        elif [ "${host_ip}" == "" ] || [ "${node_port}" == "" ] ; then
            echo "Pod hostIP and Service nodePort not found"
        else
            pod_url="http://${host_ip}:${node_port}"
            echo ""
            echo "URL: ${pod_url}"
            echo ""
            echo "---------------"
            wget -q -O- ${pod_url}
            echo "---------------"
        fi
    fi
}

# Main Exec point
if ! [ "${1}" == "" ] ; then
    get_pod_ref ${1}
else
    list_pods
fi
