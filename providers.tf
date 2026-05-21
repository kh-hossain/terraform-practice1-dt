terraform {
    required_version = "1.12.2"

    required_providers {
        google = {
            source = "hashicorp/google"
            version = ">= 7.29.0, < 8.0.0" # Recommended Fabric version range
        }

        google-beta = {
            source = "hashicorp/google-beta"
            version = ">= 7.29.0, < 8.0.0" # Recommended Fabric version range
        }
    }

    backend "gcs" {} # Further info stored in non-committed env-[ENV_NAME]-gcs.tfbackend file
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