#!/usr/bin/env bash

#
# This is the custom config for a Kubernetes Control Plane node
# For general node configuration, put that work in 'provision_base.sh'
#

# Options to ignore ssl cert errors
APT_OPTS="-o Acquire::https::Verify-Peer=false"
CURL_OPTS="--insecure"

# Install Helm Deployment Manager
sudo apt install ${APT_OPTS} -y ca-certificates curl gpg
curl ${CURL_OPTS} -fsSL https://packages.buildkite.com/helm-linux/helm-debian/gpgkey | gpg --dearmor | sudo tee /usr/share/keyrings/helm.gpg > /dev/null
echo "deb [signed-by=/usr/share/keyrings/helm.gpg] https://packages.buildkite.com/helm-linux/helm-debian/any/ any main" | sudo tee /etc/apt/sources.list.d/helm-stable-debian.list
sudo apt update ${APT_OPTS}
sudo apt install ${APT_OPTS} -y helm
