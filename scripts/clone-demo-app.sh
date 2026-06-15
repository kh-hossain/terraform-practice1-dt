#!/usr/bin/env bash
set -euo pipefail

REPO_URL="${REPO_URL:-https://github.com/atefhares/DevOps-Challenge-Demo-Code.git}"
APP_DIR="${APP_DIR:-app}"

if [[ -d "${APP_DIR}" && -n "$(find "${APP_DIR}" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
  echo "ERROR: ${APP_DIR}/ is not empty."
  echo "Move/delete its contents first, or run:"
  echo "  rm -rf ${APP_DIR:?}/* ${APP_DIR}/.[!.]* ${APP_DIR}/..?*"
  exit 1
fi

TMP_DIR="$(mktemp -d)"
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "Cloning demo app from: ${REPO_URL}"
git clone --depth 1 "${REPO_URL}" "${TMP_DIR}/repo"

mkdir -p "${APP_DIR}"

shopt -s dotglob nullglob
cp -R "${TMP_DIR}/repo"/* "${APP_DIR}/"

rm -rf "${APP_DIR}/.git" "${APP_DIR}/.github"

echo "Demo app copied into ${APP_DIR}/"
echo "Next: add Dockerfile and run scripts/build-push.sh"