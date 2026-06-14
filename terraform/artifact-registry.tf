module "artifact_registry" {
  source = "./modules/artifact-registry"

  project_id = var.project_id
  location   = var.region
  name       = "${local.name_prefix}-docker"

  reader_members = concat(
    [
      "serviceAccount:${module.gke.node_service_account_email}"
    ],
    var.artifact_registry_reader_members
  )

  writer_members = var.artifact_registry_writer_members

  labels = {
    component = "artifact-registry"
  }
}