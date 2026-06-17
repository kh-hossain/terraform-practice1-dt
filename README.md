# GCP Terraform Practice Project

This repository provisions a private Google Cloud environment with Terraform (using Fabric modules) and deploys a containerized Python/Tornado demo application to GKE. The final running application is exposed through a GKE Ingress-backed external Application Load Balancer, uses Artifact Registry for container images, and stores a shared counter in Memorystore for Redis Cluster.

## Final result

The finished system includes:

- A custom VPC.
- A restricted subnet for private GKE nodes.
- A management subnet for a private bastion VM.
- A private GKE Standard cluster.
- A bastion VM without a public IP, accessed through IAP.
- Artifact Registry for Docker images.
- Memorystore for Redis Cluster accessed privately through Private Service Connect.
- Kubernetes manifests for the app Deployment, Service, BackendConfig, and Ingress.
- Automation scripts for cloning the demo app, building/pushing the image, deploying manifests, and inspecting/resetting the Redis counter.
- Terraform remote state stored in a GCS backend with object versioning enabled on the bucket and backend state locking supported by Terraform's GCS backend.

## Demo app description

The demo app is a small Python/Tornado web application. It renders an HTML page and stores a `counter` key in Redis. Each request to `/` increments the counter and displays the current value.

The final application behavior is:

- `GET /` renders the page and increments the Redis counter.
- `GET /health` returns `ok` and does not increment the counter (branch: "update-health-check-and-redis-cluster-support").
- The app uses a Redis Cluster-aware client so that it can follow Redis Cluster slot redirects.
- The container runs as a non-root Linux user.
- Runtime configuration is injected through Kubernetes environment variables.

## Repository layout

```text
.
├── app/
│   ├── Dockerfile
│   ├── .dockerignore
│   ├── hello.py
│   ├── requirements.txt
│   ├── static/
│   └── templates/
├── docs/
│   ├── FULL_PROJECT_DOCUMENTATION.md
│   └── DEBUGGING_AND_TROUBLESHOOTING.md
├── examples/
│   ├── terraform.tfvars.example
│   └── env-dev.tfvars.example
├── k8s/
│   ├── namespace.yaml
│   ├── backendconfig.yaml
│   ├── deployment.yaml.tpl
│   ├── service.yaml
│   └── ingress.yaml
├── scripts/
│   ├── clone-demo-app.sh
│   ├── build-push.sh
│   ├── build-push-cloudbuild.sh
│   ├── deploy.sh
│   └── helper-debugging-scripts/
│       └── helper-script.sh
└── terraform/
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
        ├── network/
        ├── bastion/
        ├── gke/
        ├── artifact-registry/
        └── redis/
```

## Prerequisites

Install and configure:

- Terraform 1.12.2 or compatible configured version.
- Google Cloud CLI.
- Git.
- Either Docker Desktop or Cloud Build access.
- A Google Cloud project with billing enabled.
- A Terraform service account with the required IAM permissions.
- A GCS bucket for Terraform backend state.
- Access to impersonate the Terraform service account.

Recommended local authentication:

```bash
gcloud auth login
gcloud auth application-default login
gcloud config set project PROJECT_ID
```

## Terraform variables

Copy the provided examples:

```bash
cp examples/terraform.tfvars.example terraform/terraform.tfvars
cp examples/env-dev.tfvars.example terraform/env-dev.tfvars
```

Edit values for your project, users, and service accounts.

`terraform.tfvars` is intended for values that are reusable for your local workspace, while `env-dev.tfvars` contains environment-specific values and sensitive operational values such as the Terraform impersonation service account.

Do not commit real `.tfvars` files.

## Terraform backend initialization

The backend is defined as a partial backend in `terraform/versions.tf`:

```hcl
terraform {
  backend "gcs" {}
}
```

Backend values are supplied locally through an ignored `.tfbackend` file, for example:

```hcl
bucket = "YOUR_TF_STATE_BUCKET"
prefix = "terraform-practice1-dt/dev"
```

Initialize Terraform:

```bash
cd terraform
terraform init -backend-config=env-dev-gcs.tfbackend
```

If backend settings change:

```bash
terraform init -backend-config=env-dev-gcs.tfbackend -reconfigure
```

## Provision infrastructure

From `terraform/`:

```bash
terraform fmt -recursive
terraform validate
terraform plan -var-file="env-dev.tfvars"
terraform apply -var-file="env-dev.tfvars"
```

Useful outputs:

```bash
terraform output
terraform output -raw bastion_ssh_command
terraform output -raw demo_image_base
terraform output -raw redis_host
terraform output -raw gke_cluster_name
```

## Clone the demo app

From the repository root:

```bash
bash scripts/clone-demo-app.sh
```

This copies the demo app into `app/` and removes the nested `.git` directory so the app becomes part of this repository.

## Build and push the image

### Option 1: local Docker

```bash
bash scripts/build-push.sh
```

### Option 2: Cloud Build

```bash
bash scripts/build-push-cloudbuild.sh
```

The script reads the Artifact Registry image path from Terraform output and writes the pushed image tag into:

```text
.generated/image.env
```

## Deploy to GKE

From the repository root:

```bash
bash scripts/deploy.sh
```

The deployment script:

1. Reads Terraform outputs.
2. Reads the image tag from `.generated/image.env`.
3. Renders `k8s/deployment.yaml.tpl` into `.generated/k8s/deployment.yaml`.
4. Archives the rendered manifests.
5. Copies the archive to the private bastion through IAP.
6. Runs `kubectl apply` from the bastion against the private GKE control plane.
7. Waits for the Deployment rollout.
8. Prints pod, service, and ingress status.

## Access the app

Get the Ingress IP:

```bash
gcloud compute ssh gcp-fabric-lab-dev-bastion \
  --project=PROJECT_ID \
  --zone=us-central1-a \
  --tunnel-through-iap \
  --command "kubectl -n demo-app get ingress demo-app-ingress"
```

Open:

```text
http://INGRESS_IP/
```

Health endpoint:

```bash
curl http://INGRESS_IP/health
```

Expected health response:

```text
ok
```

## Redis helper script

The helper script can read, reset, set, list, or delete the app counter key through the running Kubernetes Deployment:

```bash
bash scripts/helper-debugging-scripts/helper-script.sh get
bash scripts/helper-debugging-scripts/helper-script.sh reset
bash scripts/helper-debugging-scripts/helper-script.sh set 100
bash scripts/helper-debugging-scripts/helper-script.sh keys
bash scripts/helper-debugging-scripts/helper-script.sh delete
```

The script connects through the bastion and runs a short Python command inside the app container, using the same Redis environment variables as the application.

## Main design choices

### Private-first design

The infrastructure is designed so that administrative and workload traffic uses private paths wherever possible:

- GKE nodes are private.
- GKE control plane public endpoint is disabled.
- The bastion has no public IP.
- SSH to the bastion uses IAP tunneling.
- Redis is private through Private Service Connect.
- Terraform uses a service account through impersonation.
- Human SSH access is granted only to explicit IAM members.

### Load balancer choice

The app is exposed using GKE Ingress with:

```yaml
kubernetes.io/ingress.class: "gce"
```

This creates an external Application Load Balancer for HTTP traffic. The Kubernetes `Service` remains `ClusterIP` and is connected to the load balancer through a Network Endpoint Group annotation.

The GKE Ingress annotation is used intentionally because GKE continues to require `kubernetes.io/ingress.class` for GKE Ingress behavior, even though Kubernetes emits a deprecation warning.

### Redis Cluster connectivity

Memorystore for Redis Cluster is connected through Private Service Connect. Private Google Access is not used for Redis Cluster data-plane access. Private Google Access helps private VMs or nodes reach Google APIs; Redis Cluster uses PSC service connectivity.

### Separate service accounts

The project uses separate identities for separate responsibilities:

- Terraform service account: applies infrastructure using impersonation.
- Bastion service account: attached to the bastion VM and granted only the roles needed for logging, monitoring, and GKE administration from the bastion.
- GKE node service account: attached to node pool VMs and granted roles needed for node operation, monitoring/logging, and Artifact Registry image pulls.
- Cloud Build service account: used by Cloud Build when using `scripts/build-push-cloudbuild.sh`.
- Human IAM members: explicitly allowed to SSH through IAP and push images when configured.

### Container security

The Dockerfile creates and uses a non-root user:

```dockerfile
RUN useradd --create-home --shell /usr/sbin/nologin appuser
USER appuser
```

This limits the impact of application compromise inside the container.

### Dockerfile layer ordering

The Dockerfile copies `requirements.txt` before copying application source:

```dockerfile
COPY requirements.txt .
RUN pip install --no-cache-dir --upgrade pip \
    && pip install --no-cache-dir -r requirements.txt
COPY . .
```

This allows Docker/Cloud Build to cache dependency installation when only application source files change.

### Terraform state

Terraform remote state is stored in GCS using the GCS backend. The state bucket has object versioning enabled for recovery. Terraform's GCS backend supports state locking, which prevents multiple state-writing operations from corrupting the state.

### No write-only Terraform arguments

No Terraform resource in this project receives application passwords, API keys, or secret payloads. The configuration uses service account impersonation, IAM, and private networking rather than writing secrets into resource arguments. Because no secrets are being written through Terraform, write-only arguments were not needed.

## Branch note: `update-health-check-and-redis-cluster-support`

The branch `update-health-check-and-redis-cluster-support` updates the app to:

- Add `/health`, which returns `ok` and does not mutate Redis.
- Point Kubernetes readiness and liveness probes to `/health`.
- Point the GCP load balancer BackendConfig health check to `/health`.
- Update the Redis client to use Redis Cluster-aware logic.
- Preserve the original app structure as much as possible.
- Use `setnx("counter", 0)` instead of resetting the counter on every pod startup.

This branch removes health check noise from the counter and avoids Redis Cluster `MOVED` redirect errors.

## Suggested Git workflow

```bash
git status
git add .
git commit -m "Document project architecture and deployment workflow"
```

Before committing, ensure real `.tfvars`, backend files, `.generated/`, and local Terraform directories are ignored.

## References

- GKE Ingress for external Application Load Balancers: https://cloud.google.com/kubernetes-engine/docs/how-to/load-balance-ingress
- GKE Ingress concepts: https://cloud.google.com/kubernetes-engine/docs/concepts/ingress
- GKE BackendConfig health checks: https://cloud.google.com/kubernetes-engine/docs/how-to/ingress-configuration
- GKE VPC-native clusters and alias IPs: https://cloud.google.com/kubernetes-engine/docs/concepts/alias-ips
- Memorystore for Redis Cluster networking: https://cloud.google.com/memorystore/docs/cluster/networking
- Terraform GCS backend: https://developer.hashicorp.com/terraform/language/backend/gcs
