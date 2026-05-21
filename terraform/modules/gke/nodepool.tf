# Fabric deletes the default node-pool and so we create a custom one with the following configuration:

module "primary_nodepool" {
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/gke-nodepool?ref=v55.4.0"

  project_id   = var.project_id
  cluster_name = module.cluster.name
  cluster_id   = module.cluster.id
  location     = module.cluster.location
  name         = local.nodepool_name

  node_locations = var.node_locations

  node_config = {
    machine_type = var.node_machine_type

    boot_disk = {
      size_gb = 30
      type    = "pd-standard"
    }

    image_type = "COS_CONTAINERD"

    shielded_instance_config = {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }

    workload_metadata_config_mode = "GKE_METADATA"
  }

  network_config = {
    enable_private_nodes = true
  }

  nodepool_config = {
    autoscaling = {
      min_node_count = var.min_node_count
      max_node_count = var.max_node_count
    }

    management = {
      auto_repair  = true
      auto_upgrade = true
    }
  }

  service_account = {
    email = module.node_sa.email

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  tags = [
    "${var.name_prefix}-gke-node"
  ]

  labels = {
    component = "gke-node"
  }

  depends_on = [
    google_service_account_iam_member.terraform_can_use_node_sa
  ]
}