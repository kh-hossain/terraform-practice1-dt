variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "Default GCP region"
}

variable "name_prefix" {
  type        = string
  description = "Prefix used for network and subnet names"
}

variable "restricted_subnet_cidr" {
  type        = string
  description = "CIDR range for the restricted GKE subnet"
}

variable "management_subnet_cidr" {
  type        = string
  description = "CIDR range for the management subnet"
}

variable "pods_secondary_cidr" {
  type        = string
  description = "Secondary CIDR range for GKE Pods"
}

variable "services_secondary_cidr" {
  type        = string
  description = "Secondary CIDR range for GKE Services"
}