# General outputs

output "project_id" {
  value = var.project_id
}

output "region" {
  value = var.region
}

# Networking outputs

output "network_name" {
  value = module.network.network_name
}

output "network_self_link" {
  value = module.network.network_self_link
}

output "restricted_subnet_name" {
  value = module.network.restricted_subnet_name
}

output "management_subnet_name" {
  value = module.network.management_subnet_name
}

output "pods_secondary_range_name" {
  value = module.network.pods_secondary_range_name
}

output "services_secondary_range_name" {
  value = module.network.services_secondary_range_name
}

output "restricted_subnet_self_link" {
  value = module.network.restricted_subnet_self_link
}

output "management_subnet_self_link" {
  value = module.network.management_subnet_self_link
}


# Bastion VM outputs

output "bastion_name" {
  value = module.bastion.name
}

output "bastion_internal_ip" {
  value = module.bastion.internal_ip
}

output "bastion_ssh_command" {
  value = module.bastion.ssh_command
}

output "bastion_zone" {
  value = module.bastion.zone
}

# GKE outputs

output "gke_cluster_name" {
  value = module.gke.cluster_name
}

output "gke_cluster_location" {
  value = module.gke.cluster_location
}

output "gke_node_service_account_email" {
  value = module.gke.node_service_account_email
}

output "gke_get_credentials_command" {
  value = module.gke.get_credentials_command
}


# Artifact Registry outputs

output "artifact_registry_name" {
  value = module.artifact_registry.name
}

output "artifact_registry_url" {
  value = module.artifact_registry.url
}

output "demo_image_base" {
  value = module.artifact_registry.demo_image_base
}


# Redis outputs

output "redis_name" {
  value = module.redis.name
}

output "redis_host" {
  value = module.redis.host
}

output "redis_port" {
  value = module.redis.port
}

output "redis_discovery_endpoints" {
  value = module.redis.discovery_endpoints
}