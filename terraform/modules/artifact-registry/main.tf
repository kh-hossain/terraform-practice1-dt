locals {
  iam = merge(
    length(var.reader_members) > 0 ? {
      "roles/artifactregistry.reader" = var.reader_members
    } : {},

    length(var.writer_members) > 0 ? {
      "roles/artifactregistry.writer" = var.writer_members
    } : {}
  )
}

module "repository" {
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/artifact-registry?ref=v55.4.0"

  project_id = var.project_id
  location   = var.location
  name       = var.name

  format = {
    docker = {
      standard = {}
    }
  }

  iam    = local.iam
  labels = var.labels
}