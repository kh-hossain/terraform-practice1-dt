#!/usr/bin/env bash

# Exit immediately on errors, treat unset variables as errors, and fail the
# script if any command in a pipeline fails.
set -euo pipefail

# Directory containing the Terraform code.
#
# Can be overridden when running the script:
#   TF_DIR=terraform bash scripts/helper-debugging-scripts/helper-script.sh get
TF_DIR="${TF_DIR:-terraform}"

# Kubernetes namespace where the demo app is deployed.
#
# Defaults to demo-app, but can be overridden if the app is deployed elsewhere.
NAMESPACE="${NAMESPACE:-demo-app}"

# Kubernetes Deployment name for the demo app.
#
# kubectl exec targets the Deployment so Kubernetes can choose one of its Pods.
DEPLOYMENT="${DEPLOYMENT:-demo-app}"

# Redis action to run.
#
# The first script argument controls the action.
# If no action is provided, default to "get".
#
# Examples:
#   bash helper-script.sh get
#   bash helper-script.sh reset
#   bash helper-script.sh set 123
ACTION="${1:-get}"

# Optional value used by the "set" action.
#
# If no value is provided, default to 0.
VALUE="${2:-0}"

# Validate that the requested action is supported.
#
# This prevents accidental execution of unexpected commands and keeps the helper
# script limited to the Redis counter operations we intentionally support.
# If ACTION is one of the allowed actions, continue. Otherwise, print usage and exit.
#
# The ) ends the pattern and starts the commands for that match.
# ;; means: end this case branch. Do not continue into the next branch.
# The * is a wildcard. It catches unsupported actions.

case "${ACTION}" in
  get|reset|set|keys|delete)
    ;;
  *)
    echo "Usage:"
    echo "  bash $0 get"
    echo "  bash $0 reset"
    echo "  bash $0 set 123"
    echo "  bash $0 keys"
    echo "  bash $0 delete"
    exit 1
    ;;
esac

# If the action is "set", require the value to be an integer.
#
# The counter is numeric, so values like "abc" should fail before reaching Redis.
# ^        start of string
# -?       optional minus sign
# [0-9]+   one or more digits
# $        end of string
#
# Valid: 0, 123, -5, 999. Invalid: abc, 12.3, 1a, empty string.
if [[ "${ACTION}" == "set" && ! "${VALUE}" =~ ^-?[0-9]+$ ]]; then
  echo "ERROR: set requires an integer value."
  exit 1
fi

# Read bastion connection details from Terraform outputs.
#
# Terraform created the bastion and knows the project, VM name, and zone, so the
# script avoids hardcoding those values.
PROJECT_ID="$(terraform -chdir="${TF_DIR}" output -raw project_id)"
BASTION_NAME="$(terraform -chdir="${TF_DIR}" output -raw bastion_name)"
BASTION_ZONE="$(terraform -chdir="${TF_DIR}" output -raw bastion_zone)"

echo "Running Redis action: ${ACTION}"

# Build the command that will run on the bastion.
#
# We run kubectl from the bastion because the GKE control plane is private and
# the bastion has the private network path to reach it.
# This creates a multi-line string or heredoc and stores it in the variable REMOTE_COMMAND.
# cat <<EOF ... EOF is called a heredoc.

# local machine
# ↓ gcloud compute ssh through IAP
# bastion VM
# ↓ kubectl exec
# one demo-app Pod
# ↓ Python Redis client
# Redis Cluster

# We do this from inside the app Pod because the Pod already has the Redis environment variables,
# and it already has private network access to Redis. So we do not need to install Redis tools locally, expose Redis publicly, or manually copy Redis connection details around.
REMOTE_COMMAND=$(cat <<EOF
set -euo pipefail

# Execute a short Python script inside one of the demo app Pods. Run an inline Python script inside the container.
#
# -n selects the Kubernetes namespace.
# exec runs a command inside the target container (Kubernetes workload).
# -i keeps stdin open so the Python code below can be passed through the heredoc.
# deploy/"${DEPLOYMENT}" targets a Pod owned by the Deployment.
# -- everything after this is the command to run inside the container
# env passes the requested action/value into the Python process.
# python - tells Python to read the script from stdin.
#
#
# python - tells Python to read the script from standard input.
# <<'PY' starts a quoted heredoc: everything until the closing PY line is passed
# to Python exactly as written.
#
# The quotes around 'PY' prevent the shell from expanding variables inside the
# Python code, which keeps Python strings, f-strings, and $ characters safe.
kubectl -n "${NAMESPACE}" exec -i deploy/"${DEPLOYMENT}" -- env REDIS_ACTION="${ACTION}" REDIS_VALUE="${VALUE}" python - <<'PY'
import os
import sys

import redis
from redis.cluster import RedisCluster
from redis.exceptions import RedisError


# Read the requested helper action from environment variables passed by kubectl exec.
action = os.getenv("REDIS_ACTION", "get")
value = os.getenv("REDIS_VALUE", "0")

# Reuse the same Redis connection settings that already exist in the app Pod.
#
# These environment variables come from the Kubernetes Deployment manifest.
redis_host = os.getenv("REDIS_HOST")
redis_port = int(os.getenv("REDIS_PORT", "6379"))
redis_db = int(os.getenv("REDIS_DB", "0"))

# Decide whether to use a Redis Cluster client or a normal Redis client.
#
# Our Memorystore deployment uses Redis Cluster, so REDIS_CLUSTER_MODE is expected
# to be true. The non-cluster branch is kept so the helper can also work with a
# basic Redis instance if we use the main branch's app or the app configuration changes later.
redis_cluster_mode = os.getenv("REDIS_CLUSTER_MODE", "true").lower() in [
    "1",
    "true",
    "yes",
]


def create_client():
    # Redis Cluster requires a cluster-aware client so MOVED redirects are
    # handled correctly.
    if redis_cluster_mode:
        return RedisCluster(
            host=redis_host,
            port=redis_port,
            # Makes Redis converts responses into normal Python strings "123", not raw bytes (b'123').
            decode_responses=True,
        )

    # Standard Redis client path for non-cluster Redis deployments.
    return redis.Redis(
        host=redis_host,
        port=redis_port,
        db=redis_db,
        decode_responses=True,
    )


try:
    # Create the Redis client from the app Pod's Redis environment variables.
    r = create_client()

    # Print the current counter value.
    if action == "get":
        print(f"counter={r.get('counter')}")

    # Reset the counter back to zero.
    elif action == "reset":
        r.set("counter", 0)
        print(f"counter reset to {r.get('counter')}")

    # Set the counter to a specific integer value.
    elif action == "set":
        r.set("counter", int(value))
        print(f"counter set to {r.get('counter')}")

    # List Redis keys.
    #
    # scan_iter is safer than KEYS for larger Redis datasets because it scans
    # incrementally instead of trying to fetch every key in one blocking command.
    #
    #
    # Redis stores data as key/value pairs. In this app, the main key we care
    # about is "counter".
    #
    # Redis also has a KEYS command, for example KEYS *, that lists matching
    # keys. However, KEYS can block Redis while it scans the whole keyspace.
    # That is okay for tiny demos, but it is bad practice for larger Redis
    # databases.
    #
    # scan_iter uses Redis SCAN behavior instead. SCAN checks keys gradually in
    # batches, which is safer because it does not try to return every key in one
    # blocking operation.
    #
    # match="*" means match all key names. The * is a wildcard.
    #
    # Examples:
    #   "*"        matches all keys
    #   "counter*" matches keys starting with counter
    #   "user:*"   matches keys starting with user:
    #
    # count=100 asks Redis to scan around 100 keys per batch. It is a hint, not
    # an exact guarantee.
    #
    # scan_iter returns an iterator, so list(...) converts the results into a
    # normal Python list that we can check and print.
    elif action == "keys":
        keys = list(r.scan_iter(match="*", count=100))
        if not keys:
            print("No keys found.")
        else:
            print("keys:")
            for key in keys:
                print(f"- {key}")
    elif action == "keys":
        keys = list(r.scan_iter(match="*", count=100))
        if not keys:
            print("No keys found.")
        else:
            print("keys:")
            for key in keys:
                print(f"- {key}")

    # Delete the counter key from Redis.
    #
    #
    # Redis delete returns the number of keys it actually deleted.
    #
    # deleted counter=1 means the "counter" key existed and Redis deleted it.
    # deleted counter=0 means Redis did not delete anything because the key was not present.
    #
    # Deleting a missing key is not treated as an error; it simply means there
    # was nothing to delete.
    elif action == "delete":
        deleted = r.delete("counter")
        print(f"deleted counter={deleted}")

        

    # This should not happen because Bash validates the action before running the Python script, but keep a defensive check here too.
    #
    # Defensive fallback for unsupported actions.
    #
    # Bash already validates ACTION before this Python script runs, so this
    # branch should normally never happen. It is kept here as a second safety
    # check in case the Python script is reused or called differently later.
    #
    # print(..., file=sys.stderr) writes the message to standard error instead
    # of standard output. Normal results like "counter=123" go to stdout; error messages should go to stderr.
    #
    # sys.exit(1) exits Python with a failure code. Because the Bash script uses
    # set -e, this non-zero exit code causes the overall helper script to fail.
    else:
        print(f"Unsupported action: {action}", file=sys.stderr)
        sys.exit(1)

# Print Redis client errors clearly and return a non-zero exit code so the Bash
# script fails if the Redis operation fails.
except RedisError as e:
    print(f"Redis error: {e}", file=sys.stderr)
    sys.exit(1)
PY
EOF
)

# SSH to the private bastion through IAP and run the Redis helper command there.
#
# The bastion then uses kubectl to exec into the app Pod and run the Python
# Redis operation from inside the cluster.
gcloud compute ssh "${BASTION_NAME}" \
  --project="${PROJECT_ID}" \
  --zone="${BASTION_ZONE}" \
  --tunnel-through-iap \
  --command "${REMOTE_COMMAND}"