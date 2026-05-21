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