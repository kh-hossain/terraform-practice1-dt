#!/usr/bin/env bash
set -euo pipefail

TF_DIR="${TF_DIR:-terraform}"
IMAGE_FILE="${IMAGE_FILE:-.generated/image.env}"
K8S_DIR="${K8S_DIR:-k8s}"
RENDER_DIR="${RENDER_DIR:-.generated/k8s}"

if [[ ! -f "${IMAGE_FILE}" ]]; then
  echo "ERROR: ${IMAGE_FILE} not found."
  echo "Run scripts/build-push-cloudbuild.sh first."
  exit 1
fi

source "${IMAGE_FILE}"

PROJECT_ID="$(terraform -chdir="${TF_DIR}" output -raw project_id)"
CLUSTER_NAME="$(terraform -chdir="${TF_DIR}" output -raw gke_cluster_name)"
CLUSTER_LOCATION="$(terraform -chdir="${TF_DIR}" output -raw gke_cluster_location)"
BASTION_NAME="$(terraform -chdir="${TF_DIR}" output -raw bastion_name)"
BASTION_ZONE="$(terraform -chdir="${TF_DIR}" output -raw bastion_zone)"
REDIS_HOST="$(terraform -chdir="${TF_DIR}" output -raw redis_host)"
REDIS_PORT="$(terraform -chdir="${TF_DIR}" output -raw redis_port)"

mkdir -p "${RENDER_DIR}"

cp "${K8S_DIR}/namespace.yaml" "${RENDER_DIR}/namespace.yaml"
cp "${K8S_DIR}/backendconfig.yaml" "${RENDER_DIR}/backendconfig.yaml"
cp "${K8S_DIR}/service.yaml" "${RENDER_DIR}/service.yaml"
cp "${K8S_DIR}/ingress.yaml" "${RENDER_DIR}/ingress.yaml"

export IMAGE REDIS_HOST REDIS_PORT

envsubst < "${K8S_DIR}/deployment.yaml.tpl" > "${RENDER_DIR}/deployment.yaml"

# Connect to bastion and apply manifests from there,
# since it has network access to the GKE cluster and also has gcloud and kubectl installed via startup script.

REMOTE_DIR="/tmp/demo-app-k8s"

echo "Preparing remote manifest directory on bastion..."
gcloud compute ssh "${BASTION_NAME}" \
  --project "${PROJECT_ID}" \
  --zone "${BASTION_ZONE}" \
  --tunnel-through-iap \
  --command "rm -rf ${REMOTE_DIR} && mkdir -p ${REMOTE_DIR}"

echo "Copying rendered Kubernetes manifests to bastion..."
gcloud compute scp --recurse "${RENDER_DIR}/." "${BASTION_NAME}:${REMOTE_DIR}" \
  --project "${PROJECT_ID}" \
  --zone "${BASTION_ZONE}" \
  --tunnel-through-iap

echo "Applying Kubernetes manifests from bastion..."
gcloud compute ssh "${BASTION_NAME}" \
  --project "${PROJECT_ID}" \
  --zone "${BASTION_ZONE}" \
  --tunnel-through-iap \
  --command "
    set -euo pipefail
    gcloud config set project ${PROJECT_ID}
    gcloud container clusters get-credentials ${CLUSTER_NAME} --region ${CLUSTER_LOCATION} --project ${PROJECT_ID} --internal-ip
    kubectl apply -f ${REMOTE_DIR}/namespace.yaml
    kubectl apply -f ${REMOTE_DIR}/backendconfig.yaml
    kubectl apply -f ${REMOTE_DIR}/deployment.yaml
    kubectl apply -f ${REMOTE_DIR}/service.yaml
    kubectl apply -f ${REMOTE_DIR}/ingress.yaml
    kubectl -n demo-app rollout status deployment/demo-app --timeout=300s
    kubectl -n demo-app get pods,svc,ingress
  "