output "id" {
  description = "Fully qualified Artifact Registry repository ID"
  value       = module.repository.id
}

output "name" {
  description = "Artifact Registry repository name"
  value       = module.repository.name
}

output "url" {
  description = "Artifact Registry repository URL"
  value       = module.repository.url
}

output "demo_image_base" {
  description = "Base image path for the demo application"
  value       = "${module.repository.url}/demo-app"
}