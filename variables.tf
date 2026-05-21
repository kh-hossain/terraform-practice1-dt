variable "environment" {
  description = "Environment name for tagging"
  type        = string
}

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