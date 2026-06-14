locals {
  cluster_name  = "${var.name_prefix}-gke"
  nodepool_name = "primary"

  node_service_account_name = "${var.name_prefix}-gke-node"
}

module "node_sa" {
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/iam-service-account?ref=v55.4.0"

  project_id   = var.project_id
  name         = local.node_service_account_name
  display_name = "GKE node pool service account"

  iam_project_roles = {
    "${var.project_id}" = [
      "roles/logging.logWriter",
      "roles/monitoring.metricWriter",
      "roles/monitoring.viewer",
      "roles/container.defaultNodeServiceAccount",
      "roles/artifactregistry.reader"
    ]
  }
}

module "cluster" {
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/gke-cluster-standard?ref=v55.4.0"

  project_id = var.project_id
  name       = local.cluster_name
  location   = var.region

  node_locations = var.node_locations

  deletion_protection = false

  access_config = {
    dns_access = {
      allow_external_traffic = false
    }

    ip_access = {
      disable_public_endpoint                        = true
      gcp_public_cidrs_access_enabled                = false
      private_endpoint_authorized_ranges_enforcement = true

      authorized_ranges = {
        bastion = "${var.bastion_internal_ip}/32"
      }
    }

    private_nodes = true
  }

  vpc_config = {
    network    = var.network_self_link
    subnetwork = var.restricted_subnet_self_link

    secondary_range_names = {
      pods     = var.pods_secondary_range_name
      services = var.services_secondary_range_name
    }
  }

  max_pods_per_node = 32
  release_channel   = "REGULAR"

  enable_features = {
    dataplane_v2      = true
    workload_identity = true
    shielded_nodes    = true
  }

  enable_addons = {
    http_load_balancing            = true
    horizontal_pod_autoscaling     = true
    gce_persistent_disk_csi_driver = true
    dns_cache                      = true
  }

  logging_config = {
    enable_system_logs    = true
    enable_workloads_logs = true
  }

  monitoring_config = {
    enable_system_metrics     = true
    enable_managed_prometheus = true
  }

  node_config = {
    service_account               = module.node_sa.email
    workload_metadata_config_mode = "GKE_METADATA"

    tags = [
      "${var.name_prefix}-gke-node"
    ]

    labels = {
      component = "gke"
    }

    depends_on = [
      module.node_sa
    ]
  }

  labels = {
    component = "gke"
  }
}

resource "google_service_account_iam_member" "terraform_can_use_node_sa" {
  service_account_id = module.node_sa.id
  role               = "roles/iam.serviceAccountUser"
  member             = "serviceAccount:${var.terraform_service_account}"
}