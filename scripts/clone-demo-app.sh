#!/usr/bin/env bash

# Exit immediately on errors, treat unset variables as errors, and fail the
# script if any command in a pipeline fails.
set -euo pipefail

# Demo app Git repository to clone.
#
# This can be overridden when running the script:
#   REPO_URL=https://github.com/example/repo.git ./scripts/clone-demo-app.sh
#
# If REPO_URL is not set, use the original demo app repository.
REPO_URL="${REPO_URL:-https://github.com/atefhares/DevOps-Challenge-Demo-Code.git}"

# Local directory where the app source code will be copied.
#
# This can be overridden when running the script:
#   APP_DIR=my-app ./scripts/clone-demo-app.sh
#
# If APP_DIR is not set, default to "app".
APP_DIR="${APP_DIR:-app}"

# Stop if APP_DIR already exists and contains at least one file or folder.
#
# This prevents accidentally overwriting local app changes, Dockerfile changes,
# templates, static assets, or other work already inside the app directory.
#
# [[ ... ]] This is Bash’s enhanced test syntax. It is used for conditions inside if.
# 
# -d checks that APP_DIR exists as a directory.
# find ... -mindepth 1 -maxdepth 1 lists only direct children of APP_DIR,
# not APP_DIR itself and not deeply nested files.
# -n checks whether find returned any output.
#
# This prevents the script from copying cloned app files over existing work.
if [[ -d "${APP_DIR}" && -n "$(find "${APP_DIR}" -mindepth 1 -maxdepth 1 2>/dev/null)" ]]; then
  echo "ERROR: ${APP_DIR}/ is not empty."
  echo "Move/delete its contents first, or run:"
  echo "  rm -rf ${APP_DIR:?}/* ${APP_DIR}/.[!.]* ${APP_DIR}/..?*"
  exit 1
fi

# Create a temporary directory for the Git clone.
#
# mktemp -d creates a unique temporary folder so we do not clone directly into
# the final app directory.
TMP_DIR="$(mktemp -d)"

# Always clean up the temporary clone directory when the script exits.
#
# trap runs the cleanup command on EXIT (event), whether the script succeeds or fails.
# rm -rf removes the temporary directory and everything inside it.
trap 'rm -rf "${TMP_DIR}"' EXIT

echo "Cloning demo app from: ${REPO_URL}"

# Clone only the latest commit from the repository.
#
# --depth 1 makes this a shallow clone, which is faster and avoids downloading
# the full Git history because we only need the current app source code.
git clone --depth 1 "${REPO_URL}" "${TMP_DIR}/repo"

# Create the final app directory if it does not already exist.
mkdir -p "${APP_DIR}"

# shopt manages Bash-specific shell options.
# -s means "set", or enable, the listed options.
#
# Make shell globs include hidden files and handle empty matches safely. Enable safer glob behavior before copying repository contents.
#
# dotglob:
#   makes * include hidden dotfiles such as .env.example or .dockerignore.
#
# nullglob:
#   makes unmatched patterns expand to nothing instead of staying as a literal string like "repo/*".

shopt -s dotglob nullglob

# Copy the cloned repository contents into APP_DIR.
#
# We copy from the temporary clone instead of keeping the clone itself so the
# project repository does not become nested inside another Git repository.
# -R copies directories recursively, so folders like templates/ and static/ are copied along with regular files.
cp -R "${TMP_DIR}/repo"/* "${APP_DIR}/"

# Remove Git metadata from the copied app.
#
# This prevents the app folder from being treated as a nested Git repository and
# keeps only the source code needed for Docker build/deploy.
rm -rf "${APP_DIR}/.git" "${APP_DIR}/.github"

echo "Demo app copied into ${APP_DIR}/"
echo "Next: add Dockerfile and run scripts/build-push.sh"