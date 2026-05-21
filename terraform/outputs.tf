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