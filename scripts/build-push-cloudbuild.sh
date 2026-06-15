#!/usr/bin/env bash
set -euo pipefail

TF_DIR="${TF_DIR:-terraform}"
APP_DIR="${APP_DIR:-app}"
IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}"

IMAGE_BASE="$(terraform -chdir="${TF_DIR}" output -raw demo_image_base)"
IMAGE="${IMAGE_BASE}:${IMAGE_TAG}"

echo "Building and pushing image with Cloud Build:"
echo "  ${IMAGE}"
echo "  ${IMAGE_BASE}:latest"

gcloud builds submit "${APP_DIR}" \
  --tag "${IMAGE}"

gcloud artifacts docker tags add \
  "${IMAGE}" \
  "${IMAGE_BASE}:latest" \
  --quiet

mkdir -p .generated
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