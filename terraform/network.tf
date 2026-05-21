locals {
  name_prefix = "${var.activity_name}-${var.environment}"
}

module "network" {
  source = "./modules/network"

  project_id = var.project_id
  region     = var.region

  name_prefix = local.name_prefix

  restricted_subnet_cidr = var.restricted_subnet_cidr
  management_subnet_cidr = var.management_subnet_cidr

  pods_secondary_cidr     = var.pods_secondary_cidr
  services_secondary_cidr = var.services_secondary_cidr
}