provider "google" {
  project                     = var.project_id
  region                      = var.region
  impersonate_service_account = var.terraform_service_account

  default_labels = local.common_labels
}

provider "google-beta" {
  project                     = var.project_id
  region                      = var.region
  impersonate_service_account = var.terraform_service_account

  default_labels = local.common_labels
}