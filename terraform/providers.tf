locals {
  common_labels = {
    managed_by  = "terraform"
    environment = replace(lower(var.environment), ".", "-")
    repo        = replace(lower(var.tf_repo_name), ".", "-")
    activity    = replace(lower(var.activity_name), ".", "-")
    owner       = replace(lower(var.owner), ".", "-")
  }
}

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