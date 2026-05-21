output "name" {
  description = "Bastion VM name"
  value       = local.bastion_name
}

output "zone" {
  description = "Bastion VM zone"
  value       = var.zone
}

output "internal_ip" {
  description = "Bastion internal IP"
  value       = module.bastion_vm.internal_ip
}

output "network_tag" {
  description = "Bastion network tag"
  value       = local.bastion_network_tag
}

output "service_account_email" {
  description = "Bastion service account email"
  value       = module.bastion_sa.email
}

output "ssh_command" {
  description = "Command to SSH into the bastion through IAP"
  value       = "gcloud compute ssh ${local.bastion_name} --project ${var.project_id} --zone ${var.zone} --tunnel-through-iap"
}