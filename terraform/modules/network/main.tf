locals {
  # Consistent name for the custom VPC.
  network_name = "${var.name_prefix}-vpc"

  # Subnet names.
  #
  # The restricted subnet hosts private application infrastructure, mainly GKE
  # nodes. The management subnet hosts admin infrastructure, mainly the bastion.
  restricted_subnet_name = "${var.name_prefix}-restricted"
  management_subnet_name = "${var.name_prefix}-management"

  # Keys used by the Fabric VPC module outputs.
  #
  # Fabric indexes regional subnets using the format:
  #   region/subnet-name
  #
  # We keep these keys in locals so outputs can reliably look up the correct
  # subnet objects after the module creates them.
  restricted_subnet_key = "${var.region}/${local.restricted_subnet_name}"
  management_subnet_key = "${var.region}/${local.management_subnet_name}"

  # Names for the GKE secondary IP ranges on the restricted subnet.
  #
  # VPC-native GKE uses:
  # - the subnet primary range for node VM IPs
  # - one secondary range for Pod IPs
  # - one secondary range for Kubernetes Service IPs
  pods_secondary_range_name     = "pods"
  services_secondary_range_name = "services"
}

module "vpc" {
  # Use the Fabric VPC module to create the custom VPC and subnets.
  #
  # The module source is pinned to v55.4.0 so upstream Fabric changes do not
  # unexpectedly change this environment.
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/net-vpc?ref=v55.4.0"

  project_id = var.project_id
  name       = local.network_name

  subnets = [
    {
      name          = local.restricted_subnet_name
      region        = var.region
      ip_cidr_range = var.restricted_subnet_cidr

      # Enable private access to Google APIs from resources without public IPs.
      #
      # This helps private resources such as GKE nodes reach Google APIs and
      # services like Artifact Registry, Cloud Logging, and Cloud Monitoring
      # without requiring public external IP addresses.
      enable_private_access = true

      # Secondary ranges used by VPC-native GKE.
      #
      # These ranges must be dedicated to GKE and should not be reused for VMs,
      # Redis, PSC, or other subnets.
      secondary_ip_ranges = {
        "${local.pods_secondary_range_name}" = {
          # Pod IP range.
          #
          # This is intentionally larger because every Kubernetes Pod receives
          # an IP address from this range.
          ip_cidr_range = var.pods_secondary_cidr
        }

        "${local.services_secondary_range_name}" = {
          # Kubernetes Service IP range.
          #
          # ClusterIP Services receive virtual IPs from this range. It is smaller
          # than the Pod range because Services are usually fewer than Pods.
          ip_cidr_range = var.services_secondary_cidr
        }
      }

      flow_logs_config = {
        # Export VPC Flow Logs in 5-second aggregation windows for more detailed
        # network visibility.
        aggregation_interval = "INTERVAL_5_SEC"

        # Sample 50% of flows.
        #
        # This gives useful visibility while reducing log volume compared with
        # sampling every flow.
        flow_sampling = 0.5

        # Include source/destination metadata such as VM, project, and region
        # information where available.
        metadata = "INCLUDE_ALL_METADATA"
      }
    },
    {
      name          = local.management_subnet_name
      region        = var.region
      ip_cidr_range = var.management_subnet_cidr

      # Enable private access to Google APIs from management resources without
      # public IPs.
      #
      # The bastion has no public IP, so this helps it reach Google APIs such as
      # GKE, Logging, Monitoring, and other control-plane services privately.
      enable_private_access = true

      flow_logs_config = {
        # Export VPC Flow Logs in 5-second aggregation windows for detailed
        # visibility into management subnet traffic.
        aggregation_interval = "INTERVAL_5_SEC"

        # Sample 50% of flows to balance visibility and log volume/cost.
        flow_sampling = 0.5

        # Include metadata to make the logs easier to investigate during
        # debugging or review.
        metadata = "INCLUDE_ALL_METADATA"
      }
    }
  ]
}