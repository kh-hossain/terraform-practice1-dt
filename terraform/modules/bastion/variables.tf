variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "zone" {
  type        = string
  description = "GCP zone for the bastion VM"
}

variable "name_prefix" {
  type        = string
  description = "Name prefix for bastion resources"
}

variable "network_name" {
  type        = string
  description = "VPC network name"
}

variable "network_self_link" {
  type        = string
  description = "VPC network self link"
}

variable "management_subnet_self_link" {
  type        = string
  description = "Management subnet self link"
}

variable "authorized_members" {
  type        = list(string)
  description = "IAM members allowed to connect to the bastion through IAP"
  default     = [] # Makes the module more flexible - even if not set, it won't cause an error
}