resource "google_project_iam_member" "os_login" {
  for_each = toset(var.authorized_members)

  project = var.project_id
  role    = "roles/compute.osLogin"
  member  = each.value
}

resource "google_iap_tunnel_instance_iam_member" "iap_tunnel_access" {
  for_each = toset(var.authorized_members)

  project  = var.project_id
  zone     = var.zone
  instance = local.bastion_name

  role   = "roles/iap.tunnelResourceAccessor"
  member = each.value

  depends_on = [module.bastion_vm]
}