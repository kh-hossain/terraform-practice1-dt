# Debugging and Troubleshooting Notes

This document records the main issues encountered while building and deploying the environment, how each issue was diagnosed, and how it was resolved.

## 1. Terraform initialization and file structure

### Symptom

Terraform was initially run before all `.tf` files existed.

### Diagnosis

`terraform init` in an empty or partial directory is harmless, but Terraform can only validate and plan after configuration files exist.

### Resolution

Created a clear Terraform layout:

```text
terraform/
├── versions.tf
├── providers.tf
├── variables.tf
├── outputs.tf
├── network.tf
├── bastion.tf
├── gke.tf
├── artifact-registry.tf
├── redis.tf
└── modules/
```

## 2. Provider labels and invalid label values

### Symptom

Terraform failed because a label value contained a dot, such as an email-derived value.

### Diagnosis

Google Cloud labels have strict character requirements. Dots in label values are invalid.

### Resolution

Sanitized labels in Terraform locals using lowercasing and replacement:

```hcl
owner = replace(lower(var.owner), ".", "-")
```

Also avoided putting raw email addresses into labels.

## 3. Network module output key mismatch

### Symptom

Subnet output lookup failed.

### Diagnosis

The Fabric VPC module returns subnet self links keyed by `region/subnet-name`, not by only `subnet-name`.

### Resolution

Created local keys:

```hcl
restricted_subnet_key = "${var.region}/${local.restricted_subnet_name}"
management_subnet_key = "${var.region}/${local.management_subnet_name}"
```

Then accessed:

```hcl
module.vpc.subnet_self_links[local.restricted_subnet_key]
```

## 4. Ubuntu 20.04 image issue

### Symptom

The bastion VM image family for Ubuntu 20.04 failed to resolve.

### Diagnosis

The requested image family did not resolve as expected in the project/image scope used.

### Resolution

Used Ubuntu 22.04 LTS:

```hcl
image = "ubuntu-os-cloud/ubuntu-2204-lts"
```

## 5. Bastion access and first SSH key prompt

### Symptom

First `gcloud compute ssh` / `gcloud compute scp` prompted about missing SSH keys and host key caching.

### Diagnosis

This is expected on first use. gcloud creates local SSH key material and caches the host key.

### Resolution

Accepted the host key prompt. Future SSH/SCP operations did not ask again.

## 6. GKE default compute service account disabled

### Symptom

GKE cluster creation failed because the default Compute Engine service account was disabled.

### Diagnosis

The GKE cluster or temporary/default node configuration attempted to use the default Compute Engine service account.

### Resolution

Created a dedicated GKE node service account and passed it to both the cluster node configuration and node pool configuration. Granted Terraform `roles/iam.serviceAccountUser` on the node service account.

## 7. GKE node boot disk too small

### Symptom

Node pool creation failed with a disk size error.

### Diagnosis

The node boot disk was smaller than the selected GKE node image required.

### Resolution

Used a larger node boot disk, such as 30 GB, while keeping the bastion disk small.

## 8. Node pool capacity and pending pod

### Symptom

Deployment timed out with one pod pending.

Events showed:

```text
0/2 nodes are available: 2 Insufficient cpu
Pod didn't trigger scale-up: 1 max node group size reached
```

### Diagnosis

The node pool autoscaling maximum was too low for two replicas plus cluster system workloads.

### Resolution

Increased:

```hcl
gke_max_node_count = 4
```

After Terraform apply, the pod triggered autoscaling and scheduled successfully.

## 9. Artifact Registry authoritative IAM bindings

### Symptom

Terraform created resources named:

```text
google_artifact_registry_repository_iam_binding.authoritative["roles/artifactregistry.reader"]
google_artifact_registry_repository_iam_binding.authoritative["roles/artifactregistry.writer"]
```

### Diagnosis

The local module passed an `iam` map into the Fabric Artifact Registry module. Fabric implements that input as authoritative IAM bindings for the given roles.

### Resolution

Kept the behavior because repository access is intended to be managed by Terraform. Noted that additive IAM could be used if external/manual IAM additions need to be preserved.

## 10. Windows Git long path error

### Symptom

Terraform module download failed on Windows due to file paths being too long in the cloned Fabric repository.

### Diagnosis

Windows Git was not configured for long paths.

### Resolution

Enabled Git long path support:

```bash
git config --global core.longpaths true
```

Then reran Terraform initialization.

## 11. Docker not installed locally

### Symptom

The local build script failed:

```text
docker: command not found
```

### Diagnosis

Docker Desktop was not installed or Docker was not on the Git Bash path.

### Resolution

Added a Cloud Build based script:

```bash
scripts/build-push-cloudbuild.sh
```

This builds the image with Cloud Build and pushes to Artifact Registry without requiring local Docker.

## 12. Cloud Build image build

### Result

Cloud Build successfully built and pushed the image to Artifact Registry. The script also added a `latest` tag and wrote `.generated/image.env`.

## 13. Redis Cluster network ID format

### Symptom

Redis Cluster creation failed:

```text
network must be set to a valid VPC network, in the form of projects/{project_id}/global/networks/{network_id}
```

### Diagnosis

The Redis Cluster resource expected the network in resource ID format, not a full HTTPS self link.

### Resolution

Changed Redis module input to:

```hcl
network_id = "projects/${var.project_id}/global/networks/${module.network.network_name}"
```

## 14. Redis uses PSC, not PGA

### Question

Why was PSC used for Redis instead of Private Google Access?

### Explanation

Memorystore for Redis Cluster uses Private Service Connect service connectivity. Private Google Access is for private access to Google APIs, not for Redis Cluster data-plane endpoints.

## 15. Deployment script SCP path issue on Windows/Git Bash

### Symptom

`gcloud compute scp --recurse` did not copy files into the expected remote path.

### Diagnosis

Recursive SCP path handling from Git Bash/Windows with remote `~` paths was unreliable.

### Resolution

Changed the deploy script to:

1. Render manifests locally.
2. Create a `.tar.gz` archive.
3. Copy the archive to the bastion.
4. Extract it into `/tmp/demo-app-k8s`.
5. Apply manifests from that directory.

This made the copy process reliable.

## 16. Ingress initially had a stale or broken external path

### Symptom

`kubectl` showed the Ingress backend as `HEALTHY`, but curling the public IP returned an empty reply.

### Diagnosis

The app and Service worked through port-forward, so the app was not the problem. The external load balancer path was suspicious.

### Resolution

Deleted and recreated the Ingress.

## 17. GKE Ingress annotation issue

### Symptom

After changing Ingress to use:

```yaml
spec:
  ingressClassName: gce
```

GKE did not create the external load balancer resources.

The Ingress had no address and no controller annotations.

### Diagnosis

GKE Ingress requires the annotation:

```yaml
kubernetes.io/ingress.class: "gce"
```

Although Kubernetes warns that the annotation is deprecated, GKE still uses it for GKE Ingress.

### Resolution

Changed `k8s/ingress.yaml` back to:

```yaml
metadata:
  annotations:
    kubernetes.io/ingress.class: "gce"
```

After redeployment, the Ingress received an external IP and the app became reachable.

## 18. Counter increased unexpectedly

### Symptom

The Redis counter increased by more than manual browser clicks.

### Diagnosis

The original health checks used `/`, and `/` increments the counter. Kubernetes readiness/liveness probes and the GCP load balancer health check were therefore mutating app state.

### Resolution

On branch `update-health-check-and-redis-cluster-support`, added `/health` to the app and changed Kubernetes and BackendConfig health checks to use `/health`.

## 19. Redis Cluster `MOVED` error

### Symptom

One pod previously restarted with:

```text
redis.exceptions.ResponseError: MOVED 6680 10.50.0.2:11007
```

### Diagnosis

The original app used a basic Redis client against Redis Cluster. Redis Cluster can redirect clients to the node responsible for a key's hash slot. A basic client does not follow the redirect automatically.

### Resolution

On branch `update-health-check-and-redis-cluster-support`, updated the app to use `RedisCluster` when `REDIS_CLUSTER_MODE=true`.

## 20. Counter reset behavior

### Symptom

The original code used:

```python
r.set("counter", 0)
```

This resets the counter whenever a pod starts.

### Resolution

Updated the code to use:

```python
r.setnx("counter", 0)
```

This initializes the counter only if it does not already exist.

## 21. Redis helper script initially produced no output

### Symptom

The helper script ran without output.

### Diagnosis

`kubectl exec` was running `python -`, but stdin was not kept open.

### Resolution

Added `-i`:

```bash
kubectl exec -i deploy/demo-app -- python -
```

The helper script then successfully read, reset, set, listed, and deleted Redis keys.

## 22. Bastion to public IP timeout

### Symptom

Curling the public Ingress IP from the bastion timed out.

### Diagnosis

The bastion has no public IP and no Cloud NAT was configured. It is designed for private administration, not general internet egress.

### Resolution

Test the public Ingress IP from the local machine or browser. Test cluster-internal paths from the bastion with `kubectl port-forward`.

## 23. Useful debugging commands

### Get pods

```bash
gcloud compute ssh gcp-fabric-lab-dev-bastion \
  --project=PROJECT_ID \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --command "kubectl -n demo-app get pods -o wide"
```

### Get events

```bash
gcloud compute ssh gcp-fabric-lab-dev-bastion \
  --project=PROJECT_ID \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --command "kubectl -n demo-app get events --sort-by=.lastTimestamp | tail -40"
```

### Check Ingress

```bash
gcloud compute ssh gcp-fabric-lab-dev-bastion \
  --project=PROJECT_ID \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --command "kubectl -n demo-app describe ingress demo-app-ingress"
```

### Test Service through port-forward

```bash
gcloud compute ssh gcp-fabric-lab-dev-bastion \
  --project=PROJECT_ID \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --command '
    kubectl -n demo-app port-forward svc/demo-app-service 8080:80 >/tmp/demo-app-port-forward.log 2>&1 &
    PF_PID=$!
    sleep 5
    curl -v --max-time 10 http://127.0.0.1:8080/ || true
    kill ${PF_PID} || true
    cat /tmp/demo-app-port-forward.log || true
  '
```

### Test individual pods

```bash
gcloud compute ssh gcp-fabric-lab-dev-bastion \
  --project=PROJECT_ID \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --command '
    for pod in $(kubectl -n demo-app get pods -l app=demo-app -o jsonpath="{.items[*].metadata.name}"); do
      echo "===== Testing pod: $pod ====="
      kubectl -n demo-app port-forward pod/$pod 18000:8000 >/tmp/pf-$pod.log 2>&1 &
      PF_PID=$!
      sleep 3
      curl -v --max-time 10 http://127.0.0.1:18000/ || true
      kill $PF_PID || true
      cat /tmp/pf-$pod.log || true
    done
  '
```

## 24. Lessons learned

- Private clusters require deployment workflows that run from an authorized private path.
- GKE Ingress can take several minutes to reconcile.
- GKE Ingress still requires `kubernetes.io/ingress.class` for GKE-specific behavior.
- `/` is a bad health check path if it changes application state.
- Redis Cluster requires cluster-aware clients.
- Terraform state should be remote, locked, and recoverable through bucket versioning.
- Service accounts should be separated by responsibility.
- Windows/Git Bash path behavior can affect SCP and module checkout workflows.
