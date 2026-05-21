variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region for the regional GKE cluster"
}

variable "name_prefix" {
  type        = string
  description = "Prefix for GKE resources"
}

variable "network_self_link" {
  type        = string
  description = "VPC network self link"
}

variable "restricted_subnet_self_link" {
  type        = string
  description = "Restricted subnet self link where private GKE nodes run"
}

variable "pods_secondary_range_name" {
  type        = string
  description = "Secondary range name for GKE Pods"
}

variable "services_secondary_range_name" {
  type        = string
  description = "Secondary range name for GKE Services"
}

variable "bastion_internal_ip" {
  type        = string
  description = "Internal IP of the bastion VM allowed to reach the GKE control plane"
}

variable "node_locations" {
  type        = list(string)
  description = "Zones where GKE nodes should run"
}

variable "node_machine_type" {
  type        = string
  description = "Machine type for GKE worker nodes"
}

variable "min_node_count" {
  type        = number
  description = "Minimum node count"
}

variable "max_node_count" {
  type        = number
  description = "Maximum node count"
}

variable "terraform_service_account" {
  type        = string
  description = "Terraform service account email used to apply infrastructure"
}