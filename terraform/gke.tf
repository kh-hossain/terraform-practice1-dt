module "gke" {
  source = "./modules/gke"

  project_id                = var.project_id
  region                    = var.region
  name_prefix               = local.name_prefix
  terraform_service_account = var.terraform_service_account

  network_self_link           = module.network.network_self_link
  restricted_subnet_self_link = module.network.restricted_subnet_self_link

  pods_secondary_range_name     = module.network.pods_secondary_range_name
  services_secondary_range_name = module.network.services_secondary_range_name

  bastion_internal_ip = module.bastion.internal_ip

  node_locations    = var.gke_node_locations
  node_machine_type = var.gke_node_machine_type
  min_node_count    = var.gke_min_node_count
  max_node_count    = var.gke_max_node_count
}