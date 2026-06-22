locals {
  # Consistent name for the GKE cluster.
  cluster_name = "${var.name_prefix}-gke"

  # Name for the primary node pool created separately from the cluster.
  nodepool_name = "primary"

  # Dedicated service account used by GKE nodes.
  #
  # This avoids using the default Compute Engine service account and keeps node
  # permissions separate from Terraform, bastion, and application identities.
  node_service_account_name = "${var.name_prefix}-gke-node"
}

module "node_sa" {
  # Use the Fabric service account module to create the GKE node service account.
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/iam-service-account?ref=v55.4.0"

  project_id   = var.project_id
  name         = local.node_service_account_name
  display_name = "GKE node pool service account"

  # Project roles granted to the service account attached to GKE node VMs.
  #
  # These are permissions for the node VM identity, not for Kubernetes users.
  iam_project_roles = {
    "${var.project_id}" = [
      # Allows node agents to write logs to Cloud Logging.
      "roles/logging.logWriter",

      # Allows node agents to write metrics to Cloud Monitoring.
      "roles/monitoring.metricWriter",

      # Allows node agents/components to view monitoring data when needed.
      #
      # This is useful for managed metrics integrations, but review whether it is
      # strictly required in a hardened production environment.
      "roles/monitoring.viewer",

      # Google-recommended role for a custom GKE node service account.
      #
      # This gives the node service account the baseline permissions expected by
      # GKE nodes without using the default Compute Engine service account.
      "roles/container.defaultNodeServiceAccount",

      # Allows GKE nodes to pull the demo app container image from Artifact Registry.
      "roles/artifactregistry.reader"
    ]
  }
}

module "cluster" {
  # Use the Fabric standard GKE cluster module.
  #
  # The module source is pinned to v55.4.0 so upstream Fabric changes do not
  # unexpectedly change this environment.
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/gke-cluster-standard?ref=v55.4.0"

  project_id = var.project_id
  name       = local.cluster_name

  # Passing a region creates a regional GKE control plane.
  location = var.region

  # Zones where worker nodes can be created.
  #
  # Example: ["us-central1-a"] keeps nodes in one zone while the cluster
  # control plane is regional.
  node_locations = var.node_locations

  # Disabled for this environment so Terraform can destroy the cluster during
  # cleanup. For long-lived production clusters, this would usually be true.
  deletion_protection = false

  # Control plane and node access configuration.
  access_config = {
    dns_access = {
      # Prevent external DNS-based access to the Kubernetes control plane.
      #
      # This supports the private admin model where access goes through the
      # bastion and the private endpoint instead of a public endpoint.
      allow_external_traffic = false
    }

    ip_access = {
      # Disable the public Kubernetes API endpoint entirely.
      #
      # Users should not access the cluster directly from the public internet.
      disable_public_endpoint = true

      # Do not allow Google-owned public CIDR ranges to access the control plane.
      #
      # This keeps the control plane access path private and restricted.

      # Do not allow the GKE control plane to be accessed from Google Cloud-owned public external IP ranges just because they belong to Google Cloud.
      # This setting is only about access to the GKE control plane, meaning the Kubernetes API endpoint used by kubectl, gcloud container clusters get-credentials, deployments, and cluster administration.

      # "Google Cloud external IPs" includes public IPs assigned to customer
      # resources such as Compute Engine VMs, Cloud Run, or Cloud Functions.
      # We do not want to trust a source just because it runs on Google Cloud.
      # Google distinguishes those from Google-reserved IP addresses, which are used for GKE cluster management and Google production services.

      gcp_public_cidrs_access_enabled = false

      # Enforce the authorized networks list for private endpoint access.
      #
      # With this enabled, private endpoint access is still restricted to the
      # CIDRs listed in authorized_ranges.
      private_endpoint_authorized_ranges_enforcement = true

      # Allow only the bastion's internal IP to reach the private control plane.
      #
      # /32 means a single host IP, not the full management subnet.
      authorized_ranges = {
        bastion = "${var.bastion_internal_ip}/32"
      }
    }

    # Create private GKE nodes with no public IP addresses.
    private_nodes = true
  }

  # Attach the cluster to the custom VPC and the restricted subnet.
  vpc_config = {
    network    = var.network_self_link
    subnetwork = var.restricted_subnet_self_link

    # VPC-native GKE uses secondary subnet ranges for Pod and Service IPs.
    #
    # This is why the cluster uses one restricted subnet with:
    # - primary range for nodes
    # - secondary range for Pods
    # - secondary range for Services
    secondary_range_names = {
      pods     = var.pods_secondary_range_name
      services = var.services_secondary_range_name
    }
  }

  # Limit pod density per node.
  #
  # This helps control Pod IP allocation from the Pods secondary range and is
  # sufficient for this small application platform.
  #
  # Limit the maximum number of Pods that can run on each node.
  #
  # This is per node, not per cluster. For example, a 4-node pool with
  # max_pods_per_node = 32 can support up to roughly 128 Pods total, before
  # accounting for GKE/system Pods.
  #
  # GKE uses this value when allocating Pod IP ranges from the Pod secondary
  # range. A lower value reduces wasted Pod IP space compared with the larger
  # default, while still leaving enough room for this small application platform.
  max_pods_per_node = 32

  # Use the Regular GKE release channel for a balance between stability and
  # receiving supported GKE updates.
  release_channel = "REGULAR"

  enable_features = {
    # Enable GKE Dataplane V2 for modern networking and improved network policy
    # behavior.
    dataplane_v2 = true

    # Enable Workload Identity so Kubernetes workloads can use Google identities
    # without storing service account keys in containers.
    # Workload Identity is not for humans logging into Pods, nodes, or the control plane. It is for applications running inside Pods to authenticate to Google Cloud APIs securely.
    workload_identity = true

    # Enable Shielded GKE nodes for VM boot integrity hardening.
    shielded_nodes = true
  }

  enable_addons = {
    # Required for GKE Ingress to create the external HTTP Application Load Balancer.
    http_load_balancing = true

    # Enables Kubernetes Horizontal Pod Autoscaling support.
    #
    # This allows workloads to scale the number of Pods based on metrics such as
    # CPU, memory, custom metrics, or external metrics.
    #
    # This does not automatically scale anything by itself. A Kubernetes HPA
    # resource must still be created for a specific Deployment.
    #
    # Cost note: the feature itself is not the main cost driver, but if HPA
    # creates more Pods and the cluster autoscaler adds more nodes, those extra
    # node resources can increase cost.
    horizontal_pod_autoscaling = true

    # Enables the GCE Persistent Disk CSI driver for workloads that need
    # persistent volumes.
    gce_persistent_disk_csi_driver = true

    # Enables NodeLocal DNSCache to improve cluster DNS performance and reliability.
    dns_cache = true
  }

  logging_config = {
    # Send GKE system component logs to Cloud Logging.
    enable_system_logs = true

    # Send application/workload logs to Cloud Logging.
    enable_workloads_logs = true
  }

  monitoring_config = {
    # Send GKE system metrics to Cloud Monitoring.
    enable_system_metrics = true

    # Enable Google-managed Prometheus for Prometheus-style Kubernetes metrics.
    #
    # This is useful for production-style observability, dashboards, and alerting,
    # especially when workloads expose Prometheus metrics.
    #
    # The demo app does not strictly require this to run. We enable it to show a
    # more complete monitoring setup.
    #
    # Cost note: Managed Prometheus can generate charges based mainly on the
    # number of metric samples ingested into Cloud Monitoring. For strict cost
    # control in a small dev environment, this can be set to false.
    enable_managed_prometheus = false
  }

  # Node configuration used by the cluster/default node configuration.
  #
  # We set this even though the primary node pool is created separately because
  # GKE may still need an initial/default node configuration during cluster
  # provisioning. This avoids falling back to the disabled/default Compute Engine
  # service account.
  node_config = {
    # Use the dedicated GKE node service account.
    service_account = module.node_sa.email

    # Use the GKE metadata server, which is required for Workload Identity.

    # Use the GKE metadata server on this node pool.
    #
    # This is required for Workload Identity Federation for GKE. It lets Pods
    # receive short-lived Google Cloud credentials through their Kubernetes
    # service account identity instead of using downloaded service account keys.
    #
    # Our current demo app does not need Google API access, but enabling this
    # makes the cluster ready for future workloads that need secure access to
    # services such as Secret Manager, Cloud Storage, or Pub/Sub.
    workload_metadata_config_mode = "GKE_METADATA"

    # Network tag applied to GKE nodes.
    #
    # This can be used later for node-targeted firewall rules if needed.
    tags = [
      "${var.name_prefix}-gke-node"
    ]

    # Labels applied to GKE node resources for inventory and filtering.
    labels = {
      component = "gke"
    }
  }

  # Labels applied to the GKE cluster resource.
  labels = {
    component = "gke"
  }

  # Ensure the node service account and its IAM roles are created before the
  # cluster tries to use it.
  depends_on = [
    module.node_sa
  ]
}

resource "google_service_account_iam_member" "terraform_can_use_node_sa" {
  # Grant the Terraform service account permission to attach/use the GKE node
  # service account when creating or updating the cluster/node pool.
  #
  # Without roles/iam.serviceAccountUser on the node service account, Terraform
  # may fail when trying to create node resources that run as this service account.
  service_account_id = module.node_sa.id
  role               = "roles/iam.serviceAccountUser"

  # The Terraform service account is passed without the "serviceAccount:" prefix,
  # so we add the IAM member prefix here.
  member = "serviceAccount:${var.terraform_service_account}"
}