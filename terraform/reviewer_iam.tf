locals {
  # Project-level read-only roles granted to reviewers.
  # These roles let reviewers inspect the deployed infrastructure, GKE resources,
  # logs, and monitoring data without giving them admin/change permissions.
  reviewer_project_roles = toset([
    "roles/compute.viewer",
    "roles/container.clusterViewer",
    "roles/container.viewer",
    "roles/monitoring.viewer",
    "roles/logging.viewer",
  ])

  # Build one IAM assignment for every combination of:
  #   reviewer member x reviewer role
  #
  # Example:
  #   reviewer_members = ["user:a@example.com", "user:b@example.com"]
  #
  # creates bindings for:
  #   user:a@example.com -> roles/compute.viewer
  #   user:a@example.com -> roles/container.viewer
  #   user:b@example.com -> roles/compute.viewer
  #   user:b@example.com -> roles/container.viewer
  #   etc.
  #
  # The map key must be unique for Terraform for_each.
  reviewer_project_iam_bindings = {
    for pair in setproduct(var.reviewer_members, local.reviewer_project_roles) :
    "${pair[0]}-${pair[1]}" => {
      member = pair[0]
      role   = pair[1]
    }
  }
}

# Grants project-level reviewer access.
#
# google_project_iam_member is additive/non-authoritative:
# it grants each member/role pair without replacing other IAM members
# that may already have the same role on the project.
resource "google_project_iam_member" "reviewer_project_roles" {
  for_each = local.reviewer_project_iam_bindings

  project = var.project_id
  role    = each.value.role
  member  = each.value.member
}