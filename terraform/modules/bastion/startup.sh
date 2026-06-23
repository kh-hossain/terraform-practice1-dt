#!/usr/bin/env bash

# Exit immediately on errors, print commands as they run, treat unset variables
# as errors, and fail pipelines if any command in the pipeline fails.
#
# This makes startup failures easier to troubleshoot from the VM serial console
# or startup-script logs.
set -euxo pipefail

# Refresh the package index so apt knows about the latest available packages.
apt-get update

# Install packages needed to add Google's apt repository securely.
#
# ca-certificates:
#   lets the VM validate HTTPS certificates.
#
# gnupg:
#   used to convert/import Google's repository signing key.
#
# curl:
#   downloads the Google Cloud apt repository signing key.
#
# apt-transport-https:
#   allows apt to use repositories served over HTTPS.
apt-get install -y ca-certificates gnupg curl apt-transport-https

# Download Google's apt repository signing key and convert it as a keyring file.
#
# The key is used by apt to verify that packages from the Google Cloud SDK
# repository are signed by Google.

# format expected by apt, and save it under /usr/share/keyrings.
#
# curl flags:
#   -f = fail on HTTP errors
#   -s = silent mode
#   -S = still show errors
#   -L = follow redirects
#
# The pipe sends the downloaded key directly into gpg.
# gpg --dearmor converts the key into apt's binary keyring format.
curl -fsSL https://packages.cloud.google.com/apt/doc/apt-key.gpg \
  | gpg --dearmor -o /usr/share/keyrings/cloud.google.gpg


# Add the Google Cloud SDK apt repository.
#
# The backslash continues the command onto the next line for readability.
# The > redirects the echo output into the repository config file.
#
# signed-by tells apt to trust this repo only when packages are signed by the
# Google key stored at /usr/share/keyrings/cloud.google.gpg
echo "deb [signed-by=/usr/share/keyrings/cloud.google.gpg] https://packages.cloud.google.com/apt cloud-sdk main" \
  > /etc/apt/sources.list.d/google-cloud-sdk.list

# Refresh the package index again so apt sees packages from the newly added
# Google Cloud SDK repository.
apt-get update

# Install admin tools used from the private bastion.
#
# google-cloud-cli:
#   provides gcloud, used to authenticate, get GKE credentials, and interact
#   with Google Cloud resources.
#
# kubectl:
#   Kubernetes CLI used to inspect/apply resources in the private GKE cluster.
#
# google-cloud-cli-gke-gcloud-auth-plugin:
#   required by kubectl/gcloud to authenticate to GKE clusters with modern
#   client authentication.
apt-get install -y \
  google-cloud-cli \
  kubectl \
  google-cloud-cli-gke-gcloud-auth-plugin