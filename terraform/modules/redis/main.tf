locals {
  # Name for the small subnet used by Private Service Connect endpoints.
  #
  # This subnet is not for VMs, GKE nodes, or Pods. It provides private IP
  # address space that Memorystore Redis Cluster can use for PSC connectivity.
  psc_subnet_name = "${var.name}-psc"

  # Name for the service connection policy that authorizes Memorystore Redis
  # Cluster to create PSC connections in this VPC.
  policy_name = "${var.name}-psc-policy"
}

resource "google_project_service" "redis" {
  project = var.project_id

  # Enable the Memorystore/Redis API so Terraform can create the Redis Cluster.
  service = "redis.googleapis.com"

  # Keep the API enabled even if this Terraform resource is destroyed.
  #
  # Disabling APIs during destroy can sometimes break cleanup of dependent
  # resources or impact other resources in the same project.
  disable_on_destroy = false
}

resource "google_project_service" "network_connectivity" {
  project = var.project_id

  # Enable the Network Connectivity API.
  #
  # This is required for the service connection policy used by Private Service Connect service connectivity automation.
  service = "networkconnectivity.googleapis.com"

  # Keep the API enabled during destroy for safer cleanup behavior.
  disable_on_destroy = false
}

resource "google_compute_subnetwork" "psc" {
  project = var.project_id
  name    = local.psc_subnet_name

  # Small CIDR range reserved for Redis Private Service Connect endpoints.
  #
  # In our environment this is a small /29 because it only needs to support PSC
  # endpoint addresses, not general workloads.
  ip_cidr_range = var.psc_subnet_cidr

  region  = var.region
  network = var.network_id

  # Enable private access to Google APIs from this subnet.
  #
  # This is a safe default for private subnets, although Redis Cluster data-plane
  # traffic itself uses PSC rather than Private Google Access.
  private_ip_google_access = true

  # Ensure the Network Connectivity API is enabled before creating resources
  # that participate in PSC service connectivity.
  depends_on = [
    google_project_service.network_connectivity
  ]
}

resource "google_network_connectivity_service_connection_policy" "redis" {
  project  = var.project_id
  name     = local.policy_name
  location = var.region

  # Service class for Memorystore Redis Cluster.
  #
  # This tells Google Cloud that this policy authorizes PSC connectivity for
  # the Redis Cluster managed service.
  service_class = "gcp-memorystore-redis"

  description = "Private Service Connect policy for Memorystore Redis Cluster"

  # VPC network where Redis PSC endpoints are allowed to be created.
  network = var.network_id

  psc_config {
    # Subnet that provides the private IP space for Redis PSC endpoints.
    #
    # The policy does not create the Redis cluster by itself. It only authorizes
    # the Redis managed service to use this subnet/network for PSC connectivity.
    subnetworks = [
      google_compute_subnetwork.psc.id
    ]
  }

  # The service connection policy requires the Network Connectivity API.
  depends_on = [
    google_project_service.network_connectivity
  ]
}

resource "google_redis_cluster" "redis" {
  project = var.project_id
  name    = var.name
  region  = var.region

  # Number of Redis shards in the cluster.
  #
  # More shards distribute data across more Redis partitions. This is part of
  # what makes this a Redis Cluster instead of a single Redis instance.
  shard_count = var.shard_count

  # Number of replicas per shard.
  #
  # Replicas improve availability compared with having only primary shards.
  replica_count = var.replica_count

  psc_configs {
    # VPC network where the Redis Cluster should expose its private PSC endpoint.
    #
    # The app receives the Redis discovery endpoint from Terraform outputs and
    # connects to it privately from GKE.
    network = var.network_id
  }

  # Disable Redis AUTH for this dev/demo deployment.
  #
  # Redis is still private-only through the VPC/PSC path, but production
  # hardening should enable authentication and update the app to use it.
  authorization_mode = "AUTH_MODE_DISABLED"

  # Disable in-transit encryption for this dev/demo deployment.
  #
  # Production hardening should enable TLS and update the Redis client
  # configuration accordingly.
  transit_encryption_mode = "TRANSIT_ENCRYPTION_MODE_DISABLED"

  # Allow Terraform to destroy the Redis Cluster during environment cleanup.
  #
  # For production, this would usually be true to prevent accidental deletion.
  deletion_protection_enabled = false

  # Redis Cluster creation depends on:
  # - the Redis API being enabled
  # - the service connection policy being created so PSC connectivity is allowed
  depends_on = [
    google_project_service.redis,
    google_network_connectivity_service_connection_policy.redis
  ]
}