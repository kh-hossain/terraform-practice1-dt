# Fabric deletes the default node-pool and so we create a custom one with the following configuration:
# Thus, the cluster module does not rely on the default GKE node pool for our workload.
# Instead, we create an explicit custom node pool so we can control the node
# service account, disk size, image type, autoscaling, security settings, and
# private-node behavior.
module "primary_nodepool" {
  # Use the Fabric GKE node pool module.
  #
  # The module source is pinned to v55.4.0 so upstream Fabric changes do not
  # unexpectedly change this environment.
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/gke-nodepool?ref=v55.4.0"

  project_id = var.project_id

  # Attach this node pool to the GKE cluster created by the cluster module.
  cluster_name = module.cluster.name
  cluster_id   = module.cluster.id
  location     = module.cluster.location

  # Name of this node pool.
  name = local.nodepool_name

  # Zones where nodes in this node pool can be created.
  #
  # Example: ["us-central1-a"] keeps the worker nodes in one zone while the
  # cluster control plane remains regional.
  node_locations = var.node_locations

  node_config = {
    # Machine type for each GKE node VM.
    #
    # This controls the CPU and memory capacity available for Pods on each node.
    machine_type = var.node_machine_type

    boot_disk = {
      # Boot disk size for each node VM.
      #
      # We use 30 GB because smaller disks can fail with some GKE node images,
      # and this gives enough room for the OS, container runtime, logs, and
      # pulled container images.
      size_gb = 30

      # Standard persistent disk is acceptable for this dev/demo node pool.
      #
      # For production or performance-sensitive workloads, pd-balanced or pd-ssd
      # could be considered.
      type = "pd-standard"
    }

    # Use Google's Container-Optimized OS image with containerd.
    #
    # COS_CONTAINERD is a hardened, GKE-optimized node image designed for running
    # containers. containerd is the Kubernetes container runtime used by GKE.
    image_type = "COS_CONTAINERD"

    shielded_instance_config = {
      # Secure Boot helps protect the node VM boot process from tampering.
      enable_secure_boot = true

      # Integrity monitoring reports boot integrity events for the node VMs.
      enable_integrity_monitoring = true
    }

    # Use the GKE metadata server on this node pool.
    #
    # This enables Workload Identity Federation for GKE at the node level.
    # Workload Identity is for Pods/applications to authenticate to Google Cloud
    # APIs using short-lived credentials, without storing service account key
    # files in Kubernetes Secrets.
    #
    # It is not used for human access to Pods, nodes, or the GKE control plane.
    # Human/admin access is handled separately through IAP, OS Login, IAM, and
    # Kubernetes RBAC.
    workload_metadata_config_mode = "GKE_METADATA"
  }

  network_config = {
    # Ensure nodes in this node pool are private.
    #
    # Private nodes do not receive public external IP addresses. They communicate
    # inside the VPC using private IPs.
    enable_private_nodes = true
  }

  nodepool_config = {
    autoscaling = {
      # Minimum number of nodes the node pool can scale down to.
      #
      # Keeping this configurable lets the environment balance availability and cost.
      min_node_count = var.min_node_count

      # Maximum number of nodes the node pool can scale up to.
      #
      # We increased this during testing because the app could not schedule all
      # Pods when the node pool was capped too low.
      max_node_count = var.max_node_count
    }

    management = {
      # Let GKE automatically recreate unhealthy nodes.
      auto_repair = true

      # Let GKE automatically upgrade nodes according to the cluster release
      # channel and maintenance behavior.
      auto_upgrade = true
    }
  }

  service_account = {
    # Attach the dedicated GKE node service account to node VMs.
    #
    # This avoids using the default Compute Engine service account and keeps node
    # permissions limited to what GKE nodes actually need.
    email = module.node_sa.email

    oauth_scopes = [
      # Give the node VM the broad Google Cloud OAuth scope.
      #
      # OAuth scopes are an older Compute Engine access-control layer. They
      # control which Google API tokens the node is allowed to request, but they
      # do not grant permissions by themselves.
      #
      # Actual permissions are still limited by the IAM roles granted to the
      # node service account, such as Artifact Registry Reader, Logging Writer,
      # Monitoring Metric Writer, and GKE node roles.
      #
      # Google recommends using the broad cloud-platform scope and enforcing
      # least privilege with IAM roles on the service account. This avoids
      # failures caused by overly narrow OAuth scopes while keeping permissions
      # controlled through IAM.
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  # Network tag applied to GKE node VMs.
  #
  # This can be used later for firewall rules that should target only GKE nodes.
  tags = [
    "${var.name_prefix}-gke-node"
  ]

  # Labels applied to the node pool/node resources for inventory and filtering.
  labels = {
    component = "gke-node"
  }

  # Ensure Terraform has permission to attach the node service account before
  # creating the node pool.
  #
  # The node service account roles define what the nodes can do after they are
  # running. This dependency is different: it ensures the Terraform service
  # account can create node VMs that run as the node service account.
  depends_on = [
    google_service_account_iam_member.terraform_can_use_node_sa
  ]
}