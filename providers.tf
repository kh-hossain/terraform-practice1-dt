terraform {
    required_version = "1.12.2"

    required_providers {
        google = {
            source = "hashicorp/google"
            version = ">= 7.29.0 < 8.0.0" # Recommended Fabric version range
        }

        google-beta = {
            source = "hashicorp/google-beta"
            version = ">= 7.29.0 < 8.0.0" # Recommended Fabric version range
        }
    }

    backend "gcs" {
    bucket = "tfstate-bucket-9ksi"
    prefix = "terraform-practice1-dt/env-dev"
  }
}

provider google {
        project = var.project_id
        region = var.region
        impersonate_service_account = var.terraform_service_account
}

provider google-beta {
    project = var.project_id
    region = var.region
    impersonate_service_account = var.terraform_service_account
}