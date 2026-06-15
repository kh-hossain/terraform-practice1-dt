#!/usr/bin/env bash
set -euo pipefail

TF_DIR="${TF_DIR:-terraform}"
APP_DIR="${APP_DIR:-app}"
IMAGE_TAG="${IMAGE_TAG:-$(git rev-parse --short HEAD 2>/dev/null || date +%Y%m%d%H%M%S)}"

IMAGE_BASE="$(terraform -chdir="${TF_DIR}" output -raw demo_image_base)"
REGISTRY_HOST="$(echo "${IMAGE_BASE}" | cut -d'/' -f1)"

echo "Configuring Docker auth for ${REGISTRY_HOST}"
gcloud auth configure-docker "${REGISTRY_HOST}" --quiet

echo "Building image:"
echo "  ${IMAGE_BASE}:${IMAGE_TAG}"
echo "  ${IMAGE_BASE}:latest"

docker build \
  -t "${IMAGE_BASE}:${IMAGE_TAG}" \
  -t "${IMAGE_BASE}:latest" \
  "${APP_DIR}"

docker push "${IMAGE_BASE}:${IMAGE_TAG}"
docker push "${IMAGE_BASE}:latest"

mkdir -p .generated
cat > .generated/image.env <<EOF
IMAGE_BASE=${IMAGE_BASE}
IMAGE_TAG=${IMAGE_TAG}
IMAGE=${IMAGE_BASE}:${IMAGE_TAG}
EOF

echo "Pushed image:"
echo "  ${IMAGE_BASE}:${IMAGE_TAG}"
echo
echo "Saved image info to .generated/image.env"