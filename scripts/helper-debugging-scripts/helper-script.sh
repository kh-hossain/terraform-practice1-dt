#!/usr/bin/env bash
set -euo pipefail

TF_DIR="${TF_DIR:-terraform}"
NAMESPACE="${NAMESPACE:-demo-app}"
DEPLOYMENT="${DEPLOYMENT:-demo-app}"

ACTION="${1:-get}"
VALUE="${2:-0}"

case "${ACTION}" in
  get|reset|set|keys|delete)
    ;;
  *)
    echo "Usage:"
    echo "  bash scripts/redis-counter.sh get"
    echo "  bash scripts/redis-counter.sh reset"
    echo "  bash scripts/redis-counter.sh set 123"
    echo "  bash scripts/redis-counter.sh keys"
    echo "  bash scripts/redis-counter.sh delete"
    exit 1
    ;;
esac

if [[ "${ACTION}" == "set" && ! "${VALUE}" =~ ^-?[0-9]+$ ]]; then
  echo "ERROR: set requires an integer value."
  echo "Example:"
  echo "  bash scripts/redis-counter.sh set 0"
  exit 1
fi

PROJECT_ID="$(terraform -chdir="${TF_DIR}" output -raw project_id)"
BASTION_NAME="$(terraform -chdir="${TF_DIR}" output -raw bastion_name)"
BASTION_ZONE="$(terraform -chdir="${TF_DIR}" output -raw bastion_zone)"

REMOTE_COMMAND=$(cat <<EOF
set -euo pipefail

kubectl -n "${NAMESPACE}" exec deploy/"${DEPLOYMENT}" -- env REDIS_ACTION="${ACTION}" REDIS_VALUE="${VALUE}" python - <<'PY'
import os
import sys

import redis
from redis.cluster import RedisCluster
from redis.exceptions import RedisError


ACTION = os.getenv("REDIS_ACTION", "get")
VALUE = os.getenv("REDIS_VALUE", "0")

REDIS_HOST = os.getenv("REDIS_HOST")
REDIS_PORT = int(os.getenv("REDIS_PORT", "6379"))
REDIS_DB = int(os.getenv("REDIS_DB", "0"))
REDIS_CLUSTER_MODE = os.getenv("REDIS_CLUSTER_MODE", "true").lower() in [
    "1",
    "true",
    "yes",
]


def create_client():
    if REDIS_CLUSTER_MODE:
        return RedisCluster(
            host=REDIS_HOST,
            port=REDIS_PORT,
            decode_responses=True,
        )

    return redis.Redis(
        host=REDIS_HOST,
        port=REDIS_PORT,
        db=REDIS_DB,
        decode_responses=True,
    )


try:
    r = create_client()

    if ACTION == "get":
        print(f"counter={r.get('counter')}")

    elif ACTION == "reset":
        r.set("counter", 0)
        print(f"counter reset to {r.get('counter')}")

    elif ACTION == "set":
        r.set("counter", int(VALUE))
        print(f"counter set to {r.get('counter')}")

    elif ACTION == "keys":
        keys = list(r.scan_iter(match="*", count=100))
        print("keys:")
        for key in keys:
            print(f"- {key}")

    elif ACTION == "delete":
        deleted = r.delete("counter")
        print(f"deleted counter={deleted}")

    else:
        print(f"Unsupported action: {ACTION}", file=sys.stderr)
        sys.exit(1)

except RedisError as e:
    print(f"Redis error: {e}", file=sys.stderr)
    sys.exit(1)
PY
EOF
)

gcloud compute ssh "${BASTION_NAME}" \
  --project="${PROJECT_ID}" \
  --zone="${BASTION_ZONE}" \
  --tunnel-through-iap \
  --command "${REMOTE_COMMAND}"