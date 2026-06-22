locals {
  # Build the IAM map expected by the Fabric Artifact Registry module.
  #
  # The Fabric module expects repository IAM in this shape:
  #   {
  #     "roles/some.role" = ["member1", "member2"]
  #   }
  #
  # We build this map conditionally so Terraform does not create empty IAM
  # bindings when no readers or writers are provided.
  iam = merge(
    # Add repository-level image pull/read access only when reader members exist.
    length(var.reader_members) > 0 ? {
      "roles/artifactregistry.reader" = var.reader_members
    } : {},

    # Add repository-level image push/write access only when writer members exist.
    length(var.writer_members) > 0 ? {
      "roles/artifactregistry.writer" = var.writer_members
    } : {}
  )
}

module "repository" {
  # Use the Google Cloud Foundation Fabric Artifact Registry module.
  # The version is pinned so future upstream module changes do not unexpectedly change this environment.
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/artifact-registry?ref=v55.4.0"

  project_id = var.project_id
  location   = var.location
  name       = var.name

  # Create a Docker/OCI Artifact Registry repository.
  #
  # Artifact Registry supports multiple repository formats, such as Docker,
  # Maven, npm, Python, Apt, and Yum. We use the Docker format because the demo
  # app is built into a container image and pushed to Artifact Registry.
  format = {
    docker = {
      # Use a standard repository, meaning this repository directly stores the
      # images we build and push.
      #
      # This is different from:
      # - a remote repository, which proxies/caches artifacts from an upstream
      #   source such as Docker Hub; or
      # - a virtual repository, which provides one endpoint in front of multiple
      #   repositories.
      standard = {}
    }
  }

  # Apply repository-level IAM generated above.
  #
  # In the Fabric module, this creates authoritative IAM bindings for the roles
  # included in local.iam. That means Terraform manages the full member list for
  # each role passed here on this repository.
  iam = local.iam

  # Apply common labels from the root module, such as environment, owner,
  # activity, repo, and component.
  labels = var.labels
}