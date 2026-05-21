locals {
  network_name = "${var.name_prefix}-vpc"

  restricted_subnet_name = "${var.name_prefix}-restricted"
  management_subnet_name = "${var.name_prefix}-management"

  restricted_subnet_key = "${var.region}/${local.restricted_subnet_name}"
  management_subnet_key = "${var.region}/${local.management_subnet_name}"

  pods_secondary_range_name     = "pods"
  services_secondary_range_name = "services"
}

module "vpc" {
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/net-vpc?ref=v55.4.0"

  project_id = var.project_id
  name       = local.network_name

  subnets = [
    {
      name                  = local.restricted_subnet_name
      region                = var.region
      ip_cidr_range         = var.restricted_subnet_cidr
      enable_private_access = true

      secondary_ip_ranges = {
        "${local.pods_secondary_range_name}" = {
          ip_cidr_range = var.pods_secondary_cidr
        }

        "${local.services_secondary_range_name}" = {
          ip_cidr_range = var.services_secondary_cidr
        }
      }

      flow_logs_config = {
        aggregation_interval = "INTERVAL_5_SEC"
        flow_sampling        = 0.5
        metadata             = "INCLUDE_ALL_METADATA"
      }
    },
    {
      name                  = local.management_subnet_name
      region                = var.region
      ip_cidr_range         = var.management_subnet_cidr
      enable_private_access = true

      flow_logs_config = {
        aggregation_interval = "INTERVAL_5_SEC"
        flow_sampling        = 0.5
        metadata             = "INCLUDE_ALL_METADATA"
      }
    }
  ]
}