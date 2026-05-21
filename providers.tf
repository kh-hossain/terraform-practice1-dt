provider "google" {
  project                     = var.project_id
  region                      = var.region
  impersonate_service_account = var.terraform_service_account

  default_labels = {
    managed_by  = "terraform" #
    environment = var.environment
    repo        = var.tf_repo_name
    activity    = var.activity_name
    owner       = var.owner
  }
}

provider "google-beta" {
  project                     = var.project_id
  region                      = var.region
  impersonate_service_account = var.terraform_service_account

  default_labels = {
    managed_by  = "terraform"
    environment = var.environment
    repo        = var.tf_repo_name
    activity    = var.activity_name
    owner       = var.owner
  }
}