locals {
  psc_subnet_name = "${var.name}-psc"
  policy_name     = "${var.name}-psc-policy"
}

resource "google_project_service" "redis" {
  project = var.project_id
  service = "redis.googleapis.com"

  disable_on_destroy = false
}

resource "google_project_service" "network_connectivity" {
  project = var.project_id
  service = "networkconnectivity.googleapis.com"

  disable_on_destroy = false
}

resource "google_compute_subnetwork" "psc" {
  project       = var.project_id
  name          = local.psc_subnet_name
  ip_cidr_range = var.psc_subnet_cidr
  region        = var.region
  network       = var.network_id

  private_ip_google_access = true

  depends_on = [
    google_project_service.network_connectivity
  ]
}

resource "google_network_connectivity_service_connection_policy" "redis" {
  project       = var.project_id
  name          = local.policy_name
  location      = var.region
  service_class = "gcp-memorystore-redis"
  description   = "Private Service Connect policy for Memorystore Redis Cluster"
  network       = var.network_id

  psc_config {
    subnetworks = [
      google_compute_subnetwork.psc.id
    ]
  }

  depends_on = [
    google_project_service.network_connectivity
  ]
}

resource "google_redis_cluster" "redis" {
  project       = var.project_id
  name          = var.name
  region        = var.region
  shard_count   = var.shard_count
  replica_count = var.replica_count

  psc_configs {
    network = var.network_id
  }

  authorization_mode      = "AUTH_MODE_DISABLED"
  transit_encryption_mode = "TRANSIT_ENCRYPTION_MODE_DISABLED"

  deletion_protection_enabled = false

  depends_on = [
    google_project_service.redis,
    google_network_connectivity_service_connection_policy.redis
  ]
}