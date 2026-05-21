# Variables for GCP project and backend configuration

variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Default GCP region"
  default     = "us-central1"
}

variable "terraform_service_account" {
  type        = string
  description = "Service account used by Terraform through impersonation"
  sensitive   = true
}


# Variables for consistent tagging across resources

variable "environment" {
  description = "Environment name for tagging"
  type        = string
}

variable "owner" {
  description = "Owner name for tagging"
  type        = string
}

variable "tf_repo_name" {
  type        = string
  description = "Name of the Terraform code repository for tagging purposes"
}

variable "activity_name" {
  type        = string
  description = "Name of the activity for tagging purposes"
}

# Variables for network configuration

variable "restricted_subnet_cidr" {
  type        = string
  description = "Primary CIDR range for the restricted subnet hosting private GKE nodes"
  default     = "10.10.0.0/24"
}

variable "management_subnet_cidr" {
  type        = string
  description = "Primary CIDR range for the management subnet hosting the bastion VM"
  default     = "10.20.0.0/24"
}

variable "pods_secondary_cidr" {
  type        = string
  description = "Secondary CIDR range for GKE Pods"
  default     = "10.30.0.0/16"
}

variable "services_secondary_cidr" {
  type        = string
  description = "Secondary CIDR range for GKE Services"
  default     = "10.40.0.0/20"
}