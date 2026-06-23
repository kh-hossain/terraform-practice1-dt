#!/usr/bin/env bash

# Exit immediately on errors, treat unset variables as errors, and fail the
# script if any command in a pipeline fails.
set -euo pipefail

# Directory containing the Terraform code.
#
# This can be overridden when running the script:
#   TF_DIR=terraform ./scripts/build-push.sh
#
# If TF_DIR is not set, default to "terraform".
TF_DIR="${TF_DIR:-terraform}"

# Directory containing the application Dockerfile and source code.
#
# Docker uses this directory as the build context.
APP_DIR="${APP_DIR:-app}"

# Image tag to use for this build.
#
# If IMAGE_TAG is already set, use it.
# Otherwise, try to use the current Git commit short SHA.
# If the command is not being run from inside a Git repo, hide the Git error
# output with 2>/dev/null and fall back to a timestamp.
#
# Examples:
#   demo-app:8bcc75a
#   demo-app:20260222153045
IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}"

# Read the base Artifact Registry image path from Terraform output.
#
# The base image path does not include the tag.
#
# Example:
#   us-central1-docker.pkg.dev/project/repository/demo-app
IMAGE_BASE="$(terraform -chdir="${TF_DIR}" output -raw demo_image_base)"

# Extract the registry hostname from the image base.
#
# For an Artifact Registry image like:
#   us-central1-docker.pkg.dev/project/repository/demo-app
#
# this returns:
#   us-central1-docker.pkg.dev
#
# Docker needs authentication configured for this registry host before pushing.

# So this extract the registry hostname from the full Artifact Registry image path.
#
# cut -d'/' -f1 splits the image path on "/" and returns the first field.
REGISTRY_HOST="$(echo "${IMAGE_BASE}" | cut -d'/' -f1)"

echo "Configuring Docker auth for ${REGISTRY_HOST}"

# Configure Docker to use gcloud as the credential helper for this Artifact
# Registry host.
#
# This lets local docker push authenticate to Artifact Registry using the active
# gcloud account.

# Artifact Registry is different. It is a Docker registry / Google API service. You authenticate to it with Docker/gcloud credentials.
# There is no GKE control-plane endpoint-like involved, so --internal-ip does not apply.
gcloud auth configure-docker "${REGISTRY_HOST}" --quiet

echo "Building image:"
echo "  ${IMAGE_BASE}:${IMAGE_TAG}"
echo "  ${IMAGE_BASE}:latest"

# Build the Docker image from APP_DIR and apply two tags:
#
# 1. A unique tag based on the Git commit SHA or timestamp.
#    This is useful for traceability and repeatable deployments.
#
# 2. The "latest" tag.
#    This is convenient for humans who want to find the newest image.
docker build \
  -t "${IMAGE_BASE}:${IMAGE_TAG}" \
  -t "${IMAGE_BASE}:latest" \
  "${APP_DIR}"

# Push the uniquely tagged image to Artifact Registry.
docker push "${IMAGE_BASE}:${IMAGE_TAG}"

# Push the latest tag to Artifact Registry.
docker push "${IMAGE_BASE}:latest"

# Create a local generated-output directory.
#
# This directory should be ignored by Git and is used to pass build information
# to later scripts.
mkdir -p .generated

# Save the image metadata for the deploy script.
#
# The deploy script can read this file so it knows exactly which image tag to
# deploy to GKE.
cat > .generated/image.env <<EOF
IMAGE_BASE=${IMAGE_BASE}
IMAGE_TAG=${IMAGE_TAG}
IMAGE=${IMAGE_BASE}:${IMAGE_TAG}
EOF

echo "Pushed image:"
echo "  ${IMAGE_BASE}:${IMAGE_TAG}"
echo
echo "Saved image info to .generated/image.env"