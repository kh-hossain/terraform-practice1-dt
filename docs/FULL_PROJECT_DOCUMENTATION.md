# Full Project Documentation

## 1. Purpose

This document explains the project from beginning to end. It covers the application, infrastructure, deployment flow, networking model, security model, Terraform module structure, container build process, Kubernetes deployment, Redis design, state management, and operational scripts.

The project provisions a private Google Cloud environment using Terraform (using Fabric modules) and deploys a containerized Python/Tornado application onto GKE. The application is exposed through a GKE-managed external Application Load Balancer and stores a shared counter in Memorystore for Redis Cluster.

## 2. Final state

The final environment contains:

- A custom VPC.
- A private/restricted subnet for GKE nodes.
- A management subnet for the bastion host.
- A private GKE Standard cluster with private nodes and private control-plane access.
- A private bastion host with no external IP.
- IAP SSH access to the bastion.
- Least-privilege IAM assignments for bastion access and GKE administration.
- A GKE node service account.
- A bastion VM service account.
- A Terraform impersonation service account.
- Artifact Registry Docker repository.
- Memorystore for Redis Cluster connected through Private Service Connect.
- Kubernetes manifests for application runtime resources.
- A GKE Ingress-backed external Application Load Balancer.
- Backend health checking through BackendConfig.
- Remote Terraform state in GCS.
- GCS object versioning enabled on the backend bucket.
- Terraform state locking through the GCS backend.
- Automation scripts for clone, build, push, deploy, and Redis counter operations.

## 3. Application

### 3.1 What the app does

The demo application is a Python/Tornado web app. It renders an HTML page and stores a counter in Redis.

Final routes:

| Path | Purpose | Mutates Redis? |
|---|---|---|
| `/` | Renders the app page and increments the counter | Yes |
| `/health` | Health endpoint for Kubernetes and load balancer checks | No |

The page includes a reload button. The button simply reloads the page. Since the root path increments Redis, every browser refresh increments the counter.

### 3.2 Redis behavior

The app reads Redis connection settings from environment variables:

- `REDIS_HOST`
- `REDIS_PORT`
- `REDIS_DB`
- `REDIS_CLUSTER_MODE`

The app uses Redis Cluster-aware logic when `REDIS_CLUSTER_MODE=true`. This matters because Redis Cluster splits keys across hash slots. If a client talks to a node that is not responsible for a key's slot, Redis returns a `MOVED` redirect. A cluster-aware client follows that redirect automatically, which is what the seperate "update-health-check-and-redis-cluster-support" achieves.

### 3.3 Health endpoint (separate branch "update-health-check-and-redis-cluster-support")

The `/health` endpoint exists so health checks do not increment the counter. It simply returns `200 OK` and `ok`.

This is better than using `/` for health checks because `/` is an application route with side effects.

## 4. Architecture

### 4.1 High-level request flow

```text
Internet user
  |
  | HTTP :80
  v
GKE Ingress / Google Cloud external Application Load Balancer
  |
  v
GKE Service: demo-app-service
  |
  v
Pod endpoints through NEG
  |
  v
Python/Tornado app container
  |
  v
Memorystore for Redis Cluster via Private Service Connect
```

### 4.2 Administrative flow

```text
Local machine
  |
  | gcloud compute ssh --tunnel-through-iap
  v
Private bastion VM
  |
  | kubectl / gcloud
  v
Private GKE control plane
```

The local machine does not connect directly to the private GKE control plane. The bastion is the controlled administrative entry point.

### 4.3 Build and deploy flow

```text
Local repo
  |
  | scripts/build-push-cloudbuild.sh
  v
Cloud Build
  |
  v
Artifact Registry Docker repository
  |
  | scripts/deploy.sh renders Kubernetes manifests
  v
Bastion through IAP
  |
  | kubectl apply
  v
GKE cluster
```

## 5. Network configuration

### 5.1 VPC

The project uses a custom VPC created through the network module. The VPC contains separate subnets for different trust zones.

### 5.2 Restricted subnet

The restricted subnet hosts private GKE worker nodes. It has:

- A primary IP range for node VM interfaces.
- A secondary IP range for Pods.
- A secondary IP range for Kubernetes Services.
- Private Google Access enabled.
- VPC flow logging enabled.

### 5.3 Management subnet

The management subnet hosts the bastion VM. The bastion:

- Has no public IP.
- Is accessed through IAP SSH tunneling.
- Is allowed to administer the private cluster.

### 5.4 PSC subnet for Redis

A small subnet, such as `/29`, is created for Private Service Connect endpoints used by Memorystore for Redis Cluster.

Redis Cluster uses Private Service Connect connectivity. Private Google Access is not sufficient for Redis Cluster data-plane access because PGA is for accessing Google APIs privately, while Redis Cluster requires private service connectivity into the VPC.

### 5.5 GKE primary and secondary ranges

A VPC-native GKE cluster does not need three separate subnets for nodes, Pods, and Services. Instead, the restricted subnet has:

```text
Restricted subnet
  primary range     -> GKE node VM IP addresses
  secondary range 1 -> Pod IP addresses
  secondary range 2 -> Kubernetes Service ClusterIP addresses
```

This is the standard VPC-native GKE model. Pods use alias IPs from the Pod secondary range. ClusterIP Services use the Services secondary range. Nodes use the subnet primary range.

This is why the Terraform design creates one restricted subnet with two secondary ranges instead of three subnets.

## 6. Security and private connectivity

### 6.1 Private GKE

The GKE cluster uses private nodes. The public control-plane endpoint is disabled. Administrative access is performed from the bastion using the internal/private endpoint.

### 6.2 Bastion access

The bastion is private and has no external IP. SSH access is through IAP tunneling. Authorized SSH users are configured through IAM:

- `roles/iap.tunnelResourceAccessor` on the bastion tunnel resource.
- `roles/compute.osLogin` for OS Login.

### 6.3 Firewall rules

The firewall allows SSH to the bastion only from the IAP TCP forwarding range. The design avoids broad SSH exposure.

### 6.4 Redis private connectivity

Redis is not public. GKE Pods connect to Redis through the private PSC endpoint.

### 6.5 Artifact Registry access

The GKE node service account is allowed to pull images from Artifact Registry. Image push access is granted to configured writer members.

### 6.6 Service account separation

Different service accounts are used for different responsibilities to avoid overloading one identity with broad permissions.

## 7. Service accounts and IAM

### 7.1 Terraform service account

The Terraform provider impersonates a Terraform service account. The human or CI identity receives permission to impersonate this service account. Terraform then applies infrastructure using that service account.

This avoids using long-lived service account keys.

### 7.2 Bastion service account

The bastion service account is created by Terraform using the service account module. It is attached to the bastion VM.

Typical roles:

- Logging writer.
- Monitoring metric writer.
- Container developer or equivalent cluster administration role required for `kubectl` actions from the bastion.

### 7.3 GKE node service account

The GKE node service account is created by Terraform and attached to the node pool. It receives only the roles required for node functionality and image pulls, such as:

- Container default node service account role.
- Artifact Registry reader.
- Logging/monitoring roles as needed.

### 7.4 Artifact Registry IAM

The Artifact Registry module receives IAM inputs for reader and writer members. Reader access includes the GKE node service account so nodes can pull application images. Writer access is granted only to configured users or automation identities.

### 7.5 Human access

Human users are added explicitly through variables such as:

```hcl
bastion_authorized_members = [
  "user:user1@company.com",
  "user:user2@company.com"
]
```

This keeps access visible in code.

## 8. Terraform structure

### 8.1 Root Terraform files

The root Terraform directory contains environment composition files:

- `versions.tf` for Terraform and provider requirements.
- `providers.tf` for Google provider configuration and impersonation.
- `variables.tf` for input variables.
- `locales.tf` for local type decalaration.
- `outputs.tf` for useful outputs.
- `network.tf` for VPC/subnets.
- `bastion.tf` for private bastion.
- `gke.tf` for GKE.
- `artifact-registry.tf` for image registry.
- `redis.tf` for Memorystore Redis Cluster.

### 8.2 Reusable local modules

Local modules live under `terraform/modules/`:

```text
terraform/modules/network
terraform/modules/bastion
terraform/modules/gke
terraform/modules/artifact-registry
terraform/modules/redis
```

The project uses Google Cloud Foundation Fabric modules for several resources and wraps them in local modules to keep the root configuration clean.

## 9. Dependencies tree

### 9.1 Infrastructure dependencies

```text
Terraform backend bucket
  -> Terraform init

VPC network
  -> restricted subnet
  -> management subnet
  -> PSC subnet for Redis

management subnet
  -> bastion VM
  -> IAP firewall rule

restricted subnet
  -> GKE private nodes
  -> Pod secondary range
  -> Service secondary range

GKE node service account
  -> GKE cluster temporary/default node configuration
  -> GKE node pool
  -> Artifact Registry pull access

Artifact Registry
  -> container image push
  -> GKE pod image pull

Redis PSC policy and subnet
  -> Redis Cluster
  -> Kubernetes app environment variables

Bastion
  -> private kubectl deployment path
```

### 9.2 Runtime dependencies

```text
Ingress
  -> Service
  -> Pod endpoints / NEG
  -> app container
  -> Redis Cluster
```

### 9.3 Script dependencies

```text
scripts/clone-demo-app.sh
  -> Git
  -> app/ directory

scripts/build-push-cloudbuild.sh
  -> Terraform output: demo_image_base
  -> Cloud Build
  -> Artifact Registry
  -> .generated/image.env

scripts/deploy.sh
  -> Terraform outputs
  -> .generated/image.env
  -> k8s/*.yaml
  -> bastion SSH/IAP
  -> kubectl on bastion

helper-script.sh
  -> Terraform outputs
  -> bastion SSH/IAP
  -> kubectl exec
  -> app container Redis client
```

## 10. Dockerfile design

### 10.1 Non-root runtime user

The Dockerfile creates a dedicated user:

```dockerfile
RUN useradd --create-home --shell /usr/sbin/nologin appuser
USER appuser
```

The app process does not run as root.

### 10.2 Layer ordering

The Dockerfile installs dependencies before copying the full application source:

```dockerfile
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt
COPY . .
```

This improves build caching because dependency installation does not need to run again when only Python/template/static files change.

### 10.3 Runtime environment

The Dockerfile sets default environment variables, but Kubernetes overrides runtime values where needed.

## 11. `.gitignore` and `.dockerignore`

### 11.1 `.gitignore`

The repository should ignore:

```gitignore
.terraform/
*.tfstate
*.tfstate.*
*.tfvars
*.tfbackend
.generated/
.env
.DS_Store
```

This prevents committing local Terraform state, backend configuration, environment-specific variables, generated manifests, and local environment files.

The lock file `.terraform.lock.hcl` should usually be committed so provider selections are repeatable.

### 11.2 `app/.dockerignore`

The Docker context should ignore:

```dockerignore
.git
.github
__pycache__/
*.pyc
*.pyo
*.pyd
.pytest_cache/
.env
README.md
tests/
```

This keeps the Docker context small and avoids copying local/development files into the image.

## 12. Remote state management

Terraform uses a GCS backend configured through partial backend configuration.

Benefits:

- State is stored remotely instead of on a developer laptop.
- State is shared across operators.
- State locking is supported by the GCS backend.
- Object versioning on the bucket allows recovery from accidental deletion or overwrite.

No secrets are intentionally stored in Terraform state through application secret resources. We did not use write-only Terraform arguments because Terraform is not writing passwords, API keys, or secret values into managed resources.

## 13. Kubernetes resources

### 13.1 Namespace

The app runs in the `demo-app` namespace.

### 13.2 Deployment

The Deployment runs the app image from Artifact Registry and injects environment variables:

- `ENVIRONMENT`
- `HOST`
- `PORT`
- `REDIS_HOST`
- `REDIS_PORT`
- `REDIS_DB`
- `REDIS_CLUSTER_MODE` (second branch only: "update-health-check-and-redis-cluster-support")

### 13.3 Service

The Service is `ClusterIP`. It maps port `80` to container port `8000`.

It includes a NEG annotation so that GKE Ingress can use container-native load balancing:

```yaml
cloud.google.com/neg: '{"ingress": true}'
```

### 13.4 BackendConfig

BackendConfig defines the GCP load balancer health check. It points to `/health` so the health checker does not increment the Redis counter.

### 13.5 Ingress

The Ingress uses:

```yaml
kubernetes.io/ingress.class: "gce"
```

This creates a GKE-managed external Application Load Balancer.

The annotation is intentionally used even though Kubernetes warns that it is deprecated, because GKE Ingress requires this annotation for GKE-specific Ingress behavior.

## 14. Load balancer choice

An external Application Load Balancer was chosen through GKE Ingress because the app is HTTP-based.

Advantages:

- Native HTTP load balancing.
- GKE-managed load balancer resources.
- Backend health checks through BackendConfig.
- Container-native load balancing through NEGs.
- Clean Kubernetes-native app exposure.

A `Service` of type `LoadBalancer` would have created a simpler network load balancer. That would be valid for basic TCP exposure, but the app is an HTTP service and the Application Load Balancer is a better fit.

## 15. Redis Cluster design

### 15.1 PSC instead of PGA

Memorystore for Redis Cluster uses Private Service Connect. Private Google Access is for private access to Google APIs from resources without public IPs. Redis Cluster needs a private service connectivity path, not a Google API access path.

### 15.2 Auth and transit encryption

The initial Redis cluster used:

```hcl
authorization_mode      = "AUTH_MODE_DISABLED"
transit_encryption_mode = "TRANSIT_ENCRYPTION_MODE_DISABLED"
```

This made the original app work quickly because it did not include Redis auth/TLS handling.

A stronger production version would enable Redis authentication and transit encryption, then update the application configuration accordingly.

### 15.3 Cluster-aware app branch

The branch `update-health-check-and-redis-cluster-support` updates the app to use `RedisCluster` when `REDIS_CLUSTER_MODE=true`. This prevents `MOVED` redirect errors from crashing the app.

## 16. How to run everything

### 16.1 Configure variables

```bash
cp examples/terraform.tfvars.example terraform/terraform.tfvars
cp examples/env-dev.tfvars.example terraform/env-dev.tfvars
```

Edit the copied files.

### 16.2 Initialize Terraform

```bash
cd terraform
terraform init -backend-config=env-dev-gcs.tfbackend
```

### 16.3 Apply infrastructure

```bash
terraform fmt -recursive
terraform validate
terraform plan -var-file="env-dev.tfvars"
terraform apply -var-file="env-dev.tfvars"
```

### 16.4 Clone app

```bash
cd ..
bash scripts/clone-demo-app.sh
```

### 16.5 Build image

```bash
bash scripts/build-push-cloudbuild.sh
```

or:

```bash
bash scripts/build-push.sh
```

### 16.6 Deploy app

```bash
bash scripts/deploy.sh
```

### 16.7 Get app URL

```bash
gcloud compute ssh gcp-fabric-lab-dev-bastion \
  --project=PROJECT_ID \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --command "kubectl -n demo-app get ingress demo-app-ingress"
```

### 16.8 Test app

```bash
curl http://INGRESS_IP/health
curl http://INGRESS_IP/
```

### 16.9 Reset Redis counter

```bash
bash scripts/helper-debugging-scripts/helper-script.sh reset
```

## 17. Operational notes

### 17.1 Ingress takes time

GKE Ingress can take several minutes to create the Google Cloud load balancer and become reachable.

### 17.2 The first request after reset shows 1

If the counter is reset to `0`, the next browser request to `/` increments the counter and usually displays `1`.

### 17.3 Backend health is visible in Ingress annotations

Check:

```bash
kubectl -n demo-app describe ingress demo-app-ingress
```

Look for:

```text
ingress.kubernetes.io/backends: {... "HEALTHY" ...}
```

### 17.4 Pod restarts should be watched

```bash
kubectl -n demo-app get pods
```

If restart counts increase, check logs:

```bash
kubectl -n demo-app logs -l app=demo-app --tail=200 --prefix
```

## 18. Branch note: `update-health-check-and-redis-cluster-support`

This branch exists to make the app more compatible with the final infrastructure. It adds:

- `/health` endpoint.
- Kubernetes probes pointing to `/health`.
- Load balancer BackendConfig health check pointing to `/health`.
- Redis Cluster-aware client support.
- Optional: `setnx("counter", 0)` to avoid resetting the counter on pod restart.

The branch is useful because it preserves the app’s main behavior while fixing health check side effects and Redis Cluster redirects.

## 19. References

- GKE Ingress external Application Load Balancer: https://cloud.google.com/kubernetes-engine/docs/how-to/load-balance-ingress
- GKE Ingress concepts: https://cloud.google.com/kubernetes-engine/docs/concepts/ingress
- BackendConfig and health checks: https://cloud.google.com/kubernetes-engine/docs/how-to/ingress-configuration
- VPC-native GKE / alias IPs: https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips
- Memorystore for Redis Cluster networking: https://cloud.google.com/memorystore/docs/cluster/networking
- Terraform GCS backend: https://developer.hashicorp.com/terraform/language/backend/gcs
