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
    echo "  bash $0 get"
    echo "  bash $0 reset"
    echo "  bash $0 set 123"
    echo "  bash $0 keys"
    echo "  bash $0 delete"
    exit 1
    ;;
esac

if [[ "${ACTION}" == "set" && ! "${VALUE}" =~ ^-?[0-9]+$ ]]; then
  echo "ERROR: set requires an integer value."
  exit 1
fi

PROJECT_ID="$(terraform -chdir="${TF_DIR}" output -raw project_id)"
BASTION_NAME="$(terraform -chdir="${TF_DIR}" output -raw bastion_name)"
BASTION_ZONE="$(terraform -chdir="${TF_DIR}" output -raw bastion_zone)"

echo "Running Redis action: ${ACTION}"

REMOTE_COMMAND=$(cat <<EOF
set -euo pipefail

kubectl -n "${NAMESPACE}" exec -i deploy/"${DEPLOYMENT}" -- env REDIS_ACTION="${ACTION}" REDIS_VALUE="${VALUE}" python - <<'PY'
import os
import sys

import redis
from redis.cluster import RedisCluster
from redis.exceptions import RedisError


action = os.getenv("REDIS_ACTION", "get")
value = os.getenv("REDIS_VALUE", "0")

redis_host = os.getenv("REDIS_HOST")
redis_port = int(os.getenv("REDIS_PORT", "6379"))
redis_db = int(os.getenv("REDIS_DB", "0"))
redis_cluster_mode = os.getenv("REDIS_CLUSTER_MODE", "true").lower() in [
    "1",
    "true",
    "yes",
]


def create_client():
    if redis_cluster_mode:
        return RedisCluster(
            host=redis_host,
            port=redis_port,
            decode_responses=True,
        )

    return redis.Redis(
        host=redis_host,
        port=redis_port,
        db=redis_db,
        decode_responses=True,
    )


try:
    r = create_client()

    if action == "get":
        print(f"counter={r.get('counter')}")

    elif action == "reset":
        r.set("counter", 0)
        print(f"counter reset to {r.get('counter')}")

    elif action == "set":
        r.set("counter", int(value))
        print(f"counter set to {r.get('counter')}")

    elif action == "keys":
        keys = list(r.scan_iter(match="*", count=100))
        if not keys:
            print("No keys found.")
        else:
            print("keys:")
            for key in keys:
                print(f"- {key}")

    elif action == "delete":
        deleted = r.delete("counter")
        print(f"deleted counter={deleted}")

    else:
        print(f"Unsupported action: {action}", file=sys.stderr)
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