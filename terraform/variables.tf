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


# Bastion VM variables

variable "bastion_zone" {
  type        = string
  description = "Zone where the bastion VM will be created"
  default     = "us-central1-a"
}

variable "bastion_authorized_members" {
  type        = list(string)
  description = "IAM members allowed to SSH to the bastion through IAP"
  default     = [] # Makes the module more flexible - even if not set, it won't cause an error

  # Example:
  # ["user:your-email@example.com"]
}

# GKE cluster variables

variable "gke_node_locations" {
  type        = list(string)
  description = "Zones where GKE worker nodes should run"
  default     = ["us-central1-a"]
}

variable "gke_node_machine_type" {
  type        = string
  description = "Machine type for GKE worker nodes"
  default     = "e2-medium"
}

variable "gke_min_node_count" {
  type        = number
  description = "Minimum number of nodes in the GKE node pool"
  default     = 1
}

variable "gke_max_node_count" {
  type        = number
  description = "Maximum number of nodes in the GKE node pool"
  default     = 2
}



# Artifact Registry variables

variable "artifact_registry_reader_members" {
  type        = list(string)
  description = "Additional IAM members allowed to read/pull images from Artifact Registry"
  default     = []
}

variable "artifact_registry_writer_members" {
  type        = list(string)
  description = "IAM members allowed to push images to Artifact Registry"
  default     = []
}


# Redis variables

variable "redis_psc_subnet_cidr" {
  type        = string
  description = "CIDR range for the Private Service Connect subnet used by Memorystore Redis Cluster"
  default     = "10.50.0.0/29" # A /29 is tiny but intentional here because it is for PSC endpoints, not for app pods or nodes.
}

variable "redis_shard_count" {
  type        = number
  description = "Number of Redis Cluster shards"
  default     = 3
}

variable "redis_replica_count" {
  type        = number
  description = "Number of replicas per Redis shard"
  default     = 1
}



