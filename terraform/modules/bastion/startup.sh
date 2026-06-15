#!/usr/bin/env bash
set -euxo pipefail

apt-get update
apt-get install -y ca-certificates gnupg curl apt-transport-https

curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
  | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg

echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
  > /etc/apt/sources.list.d/google-cloud-sdk.list

apt-get update
apt-get install -y \
  google-cloud-cli \
  kubectl \
  google-cloud-cli-gke-gcloud-auth-plugin