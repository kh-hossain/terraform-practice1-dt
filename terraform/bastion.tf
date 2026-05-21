module "bastion" {
  source = "./modules/bastion"

  project_id  = var.project_id
  region      = var.region
  zone        = var.bastion_zone
  name_prefix = local.name_prefix

  network_name                = module.network.network_name
  network_self_link           = module.network.network_self_link
  management_subnet_self_link = module.network.management_subnet_self_link

  authorized_members = var.bastion_authorized_members
}