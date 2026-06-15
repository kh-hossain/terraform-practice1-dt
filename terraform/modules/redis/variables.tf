variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "region" {
  type        = string
  description = "GCP region"
}

variable "name" {
  type        = string
  description = "Redis cluster name"
}

variable "network_id" {
  type        = string
  description = "VPC network ID or self link used by Memorystore Redis Cluster"
}

variable "psc_subnet_cidr" {
  type        = string
  description = "CIDR range for the Private Service Connect subnet"
}

variable "shard_count" {
  type        = number
  description = "Redis Cluster shard count"
  default     = 3
}

variable "replica_count" {
  type        = number
  description = "Redis replica count per shard"
  default     = 1
}

variable "labels" {
  type        = map(string)
  description = "Labels for Redis resources that support labels"
  default     = {}
}