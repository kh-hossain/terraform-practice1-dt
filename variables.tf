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