#!/usr/bin/env bash

#
# Script To Install and Configure The Ingress Nginx Controller.
#
# Resources:
# - https://kubernetes.github.io/ingress-nginx
#

# MetalLB Load Balancer Parameters
NAMESPACE="ingress-nginx"
SERVICE="ingress-nginx"

# Install The Ingress Nginx Controller
function ingress_install_helm() {
    HELM_CHART=ingress-nginx
    echo "🛠  Set up Ingress Nginx Controller"
    echo "⚙️  Add ${HELM_CHART} Helm repository"
    helm repo add ${HELM_CHART} https://kubernetes.github.io/ingress-nginx

    echo "🚜  Deploy '${SERVICE}' Helm chart"
    helm upgrade --install ${SERVICE} ${HELM_CHART} --namespace ${NAMESPACE} --create-namespace
}

#
# Main Execution Loop
#
ingress_install_helm
