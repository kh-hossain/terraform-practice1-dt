#!/usr/bin/env bash

# Exit immediately on errors, treat unset variables as errors, and fail the
# script if any command in a pipeline fails.
#
# Unlike the bastion startup script, this does not use -x because we do not
# necessarily need to print every command while building/pushing images.
set -euo pipefail

# Directory containing the Terraform code.
#
# The value can be overridden when running the script:
#   TF_DIR=terraform ./scripts/build-push-cloudbuild.sh
#
# If TF_DIR is not set, default to "terraform".
TF_DIR="${TF_DIR:-terraform}"

# Directory containing the application Dockerfile and source code.
#
# Cloud Build uses this directory as the build context.
APP_DIR="${APP_DIR:-app}"

# Image tag to use for this build.
#
# If IMAGE_TAG is already set, use it.
# Otherwise, try to use the current Git commit short SHA.
# If the command is not being run from a Git repo, fall back to a timestamp.
#
# Examples:
#   demo-app:8bcc75a
#   demo-app:20260222153045

# Try to use the current Git commit short SHA as the image tag.
#
# git rev-parse --short HEAD returns a short version of the current commit ID,
# for example "8bcc75a". This makes the container image traceable back to the
# source code version that produced it.
#
# 2>/dev/null hides Git error output if the command is not being run from inside
# a Git repository. In that case, the script falls back to using a timestamp.

# 1 = stdout = normal output
# 2 = stderr = error output
git rev-parse --short HEAD 2>/dev/null
IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}"

# Read the base Artifact Registry image path from Terraform output.
#
# Terraform knows the project, region, repository name, and app image name, so
# the script does not hardcode the image registry path.
#
# Example output:
#   us-central1-docker.pkg.dev/project/repo/demo-app
IMAGE_BASE="$(terraform -chdir="${TF_DIR}" output -raw demo_image_base)"

# Full image reference for this build.
#
# Example:
#   us-central1-docker.pkg.dev/project/repo/demo-app:8bcc75a
IMAGE="${IMAGE_BASE}:${IMAGE_TAG}"

echo "Building and pushing image with Cloud Build:"
echo "  ${IMAGE}"
echo "  ${IMAGE_BASE}:latest"

# Submit the app directory to Google Cloud Build.
#
# Cloud Build builds the Docker image using the Dockerfile inside APP_DIR and
# pushes the image to Artifact Registry with the tag stored in IMAGE.
#
# This avoids needing Docker installed locally on the workstation.
gcloud builds submit "${APP_DIR}" \
  --tag "${IMAGE}"

# Add or update the "latest" tag so it points to the same image that was just
# built and pushed.
#
# The unique IMAGE_TAG gives us an immutable-ish deployment reference, while
# "latest" gives humans an easy way to find the most recent build.
gcloud artifacts docker tags add \
  "${IMAGE}" \
  "${IMAGE_BASE}:latest" \
  --quiet

# Create a local generated-output directory.
#
# This directory is ignored by Git and stores build metadata used by later
# scripts, especially the deploy script.
mkdir -p .generated

# Save image information to a small env file.
#
# The deploy script can source/read this file so it knows exactly which image
# tag should be deployed to GKE.
cat > .generated/image.env <<EOF
IMAGE_BASE=${IMAGE_BASE}
IMAGE_TAG=${IMAGE_TAG}
IMAGE=${IMAGE}
EOF

echo "Pushed image:"
echo "  ${IMAGE}"
echo "Tagged latest:"
echo "  ${IMAGE_BASE}:latest"
echo
echo "Saved image info to .generated/image.env"