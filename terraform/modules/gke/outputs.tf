output "cluster_name" {
  description = "GKE cluster name"
  value       = module.cluster.name
}

output "cluster_location" {
  description = "GKE cluster location"
  value       = module.cluster.location
}

output "cluster_endpoint" {
  description = "GKE private endpoint"
  value       = module.cluster.endpoint
}

output "node_service_account_email" {
  description = "GKE node service account email"
  value       = module.node_sa.email
}

output "get_credentials_command" {
  description = "Command to fetch GKE credentials from the bastion or an authorized network"
  value       = "gcloud container clusters get-credentials ${module.cluster.name} --region ${module.cluster.location} --project ${var.project_id}"
}