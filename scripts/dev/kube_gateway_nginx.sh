#!/usr/bin/env bash

#
# Script To Install and Configure The Nginx Gateway Fabric.
#
# Resources:
# - https://docs.nginx.com/nginx-gateway-fabric
# - https://docs.nginx.com/nginx-gateway-fabric/install
# - https://github.com/nginx/nginx-gateway-fabric
# 
# Live Webinar: Simplify Your Kubernetes Connectivity with NGINX Gateway Fabric
# - https://youtu.be/8PNpfUt4E6g?si=V4xuDavRYFNQ4-8J&t=2515
#
# Each of the steps / functions in this script correspond to one of the steps
# outlined in the installation documentation supplied by Nginx. It's not radical
#
# Kubernetes and Helm Parameters
NAMESPACE=nginx-gateway
SERVICE=ngf
HELM_CHART=nginx-gateway-fabric

# Create the namespace for everything else
function create_gateway_namespace() {
    echo "⚙️  Create Gateway namespace"
    kubectl create namespace ${NAMESPACE}
}

# Install Certificates
# https://docs.nginx.com/nginx-gateway-fabric/install/secure-certificates
#
# https://cert-manager.io/docs/installation/kubectl/
# https://cert-manager.io/docs/installation/helm
# https://cert-manager.io/docs/reference/cmctl
function cert_manager_install() {
    CERT_NAMESPACE=cert-manager
    CERT_SERVICE=cert-manager
    CERT_HELM_AUTHOR=jetstack
    CERT_HELM_CHART=cert-manager

    echo "🚜  Pulling '${CERT_SERVICE}' Command Line Tool from GitHub"
    curl -fsSL -o cmctl https://github.com/cert-manager/cmctl/releases/latest/download/cmctl_linux_amd64

    echo "🛠   Set up '${CERT_SERVICE}' Command Line Tool"
    sudo chmod +x cmctl
    sudo chown $(id -u):$(id -g) cmctl
    sudo mv cmctl /usr/local/bin

    # Install from the cert-manager release manifest
    echo "🚜  Apply '${CERT_SERVICE}' Release Manifest"
    kubectl apply -f https://github.com/cert-manager/cert-manager/releases/download/v1.18.2/cert-manager.yaml --validate=false

#    echo "🛠   Set up Certificate Manager"
#    echo "⚙️  Add '${CERT_HELM_AUTHOR}' Helm repository"
#    helm repo add ${CERT_HELM_AUTHOR} https://charts.jetstack.io --force-update
#
#    echo "🚜  Deploy '${CERT_HELM_CHART}' Helm chart"
#    helm install ${CERT_SERVICE} ${CERT_HELM_AUTHOR}/${CERT_HELM_CHART} \
#      --create-namespace --namespace ${CERT_NAMESPACE} \
#      --version v1.18.2 \
#      --set config.apiVersion="controller.config.cert-manager.io/v1alpha1" \
#      --set config.kind="ControllerConfiguration" \
#      --set config.enableGatewayAPI=true \
#      --set crds.enabled=true
}

function create_ca_issuer() {
    echo "⚙️  Create Certificate Authority Issuer"

    # Do NOT modify or change the spacing between these lines!
    # ----------------------------------------------
    kubectl apply -f - <<EOF
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: selfsigned-issuer
  namespace: ${NAMESPACE}
spec:
  selfSigned: {}
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: nginx-gateway-ca
  namespace: ${NAMESPACE}
spec:
  isCA: true
  commonName: nginx-gateway
  secretName: nginx-gateway-ca
  privateKey:
    algorithm: RSA
    size: 2048
  issuerRef:
    name: selfsigned-issuer
    kind: Issuer
    group: cert-manager.io
---
apiVersion: cert-manager.io/v1
kind: Issuer
metadata:
  name: nginx-gateway-issuer
  namespace: ${NAMESPACE}
spec:
  ca:
    secretName: nginx-gateway-ca
EOF
    # ----------------------------------------------
    #
}

function create_certificates() {
    # The full service name is of the format: 
    # <helm-release-name>-nginx-gateway-fabric.<namespace>.svc
    # or for this script:
    # ${SERVICE}-nginx-gateway-fabric.${NAMESPACE}.svc

    # The default Helm release name used in the docs is ngf, 
    # and the default namespace is nginx-gateway, so 
    # the dnsName should be:
    #
    # ngf-nginx-gateway-fabric.nginx-gateway.svc
    #

    echo "⚙️  Create Server Certificate"

    # Do NOT modify or change the spacing between these lines!
    # ----------------------------------------------
    kubectl apply -f - <<EOF
---
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: nginx-gateway
  namespace: ${NAMESPACE}
spec:
  secretName: server-tls
  usages:
  - digital signature
  - key encipherment
  dnsNames:
  - ${SERVICE}-nginx-gateway-fabric.${NAMESPACE}.svc # this value may need to be updated
  issuerRef:
    name: nginx-gateway-issuer
EOF
    # ----------------------------------------------
    #

    echo "⚙️  Create Client Certificate"

    # Do NOT modify or change the spacing between these lines!
    # ----------------------------------------------
    kubectl apply -f - <<EOF
apiVersion: cert-manager.io/v1
kind: Certificate
metadata:
  name: nginx
  namespace: ${NAMESPACE}
spec:
  secretName: agent-tls
  usages:
  - "digital signature"
  - "key encipherment"
  dnsNames:
  - "*.cluster.local"
  issuerRef:
    name: nginx-gateway-issuer
EOF
    # ----------------------------------------------
    #
}

function verify_secrets_created() {
    kubectl get secrets --namespace ${NAMESPACE}

# Should see something like the following, which can be validated
# with some JSON snooping
# agent-tls          kubernetes.io/tls   3      3s
# nginx-gateway-ca   kubernetes.io/tls   3      15s
# server-tls         kubernetes.io/tls   3      8s

}

function nginx_gateway_api_resources_install() {
    echo "🛠  Set up Nginx Gateway API Resources"

    # install Gateway API resources
    kubectl kustomize "https://github.com/nginx/nginx-gateway-fabric/config/crd/gateway-api/standard?ref=v2.1.4" | kubectl apply -f -
}


# Install The Nginx Gateway Fabric
# https://docs.nginx.com/nginx-gateway-fabric/install/helm
function nginx_gateway_install() {
    echo "🛠  Set up Nginx Gateway Fabric"

    echo "⚙️  Grab '${HELM_CHART}' Helm chart"
    helm install ${SERVICE} oci://ghcr.io/nginx/charts/${HELM_CHART} --namespace ${NAMESPACE} --create-namespace

    echo "🚜  Deploy '${HELM_CHART}' Helm chart"
    helm install ${SERVICE} . --namespace ${NAMESPACE} --create-namespace

    echo "⏳  Verify Service '${SERVICE}' is Available"
    kubectl wait --timeout=5m --namespace ${NAMESPACE} deployment/${SERVICE}-nginx-gateway-fabric --for=condition=Available
}

#
# Main Execution Loop
#
create_gateway_namespace
cert_manager_install
create_ca_issuer
create_certificates
verify_secrets_created
nginx_gateway_api_resources_install
nginx_gateway_install
