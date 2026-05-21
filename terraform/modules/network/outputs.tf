output "network_name" {
  description = "VPC network name"
  value       = module.vpc.name
}

output "network_self_link" {
  description = "VPC network self link"
  value       = module.vpc.self_link
}

output "restricted_subnet_name" {
  description = "Restricted subnet name for private GKE nodes"
  value       = local.restricted_subnet_name
}

output "restricted_subnet_key" {
  description = "Fabric subnet map key for the restricted subnet"
  value       = local.restricted_subnet_key
}

output "restricted_subnet_self_link" {
  description = "Restricted subnet self link"
  value       = module.vpc.subnet_self_links[local.restricted_subnet_key]
}

output "management_subnet_name" {
  description = "Management subnet name for the bastion VM"
  value       = local.management_subnet_name
}

output "management_subnet_key" {
  description = "Fabric subnet map key for the management subnet"
  value       = local.management_subnet_key
}

output "management_subnet_self_link" {
  description = "Management subnet self link"
  value       = module.vpc.subnet_self_links[local.management_subnet_key]
}

output "pods_secondary_range_name" {
  description = "Secondary range name for GKE Pods"
  value       = local.pods_secondary_range_name
}

output "services_secondary_range_name" {
  description = "Secondary range name for GKE Services"
  value       = local.services_secondary_range_name
}