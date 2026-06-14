variable "project_id" {
  type        = string
  description = "GCP project ID"
}

variable "location" {
  type        = string
  description = "Artifact Registry location"
}

variable "name" {
  type        = string
  description = "Artifact Registry repository name"
}

variable "reader_members" {
  type        = list(string)
  description = "IAM members allowed to read/pull images"
  default     = []
}

variable "writer_members" {
  type        = list(string)
  description = "IAM members allowed to push images"
  default     = []
}

variable "labels" {
  type        = map(string)
  description = "Labels to attach to the repository"
  default     = {}
}