locals {
  # Consistent names for all bastion-related resources.
  bastion_name    = "${var.name_prefix}-bastion"
  bastion_sa_name = "${var.name_prefix}-bastion"

  # Network tag used by the firewall rule to target only the bastion VM.
  # This is safer than opening SSH to every VM in the subnet.
  bastion_network_tag = "${var.name_prefix}-bastion-ssh"
}

module "bastion_sa" {
  # Use the Fabric service account module to create and manage the bastion VM service account consistently with the rest of the Terraform code.
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/iam-service-account?ref=v55.4.0"

  project_id   = var.project_id
  name         = local.bastion_sa_name
  display_name = "Bastion VM service account"

  # Project roles granted to the service account attached to the bastion VM.
  #
  # These are permissions for the VM's identity, not for human users.
  iam_project_roles = {
    "${var.project_id}" = [
      # Allows the bastion VM to write logs to Cloud Logging.
      "roles/logging.logWriter",

      # Allows the bastion VM to write VM/application metrics to Cloud Monitoring.
      "roles/monitoring.metricWriter",

      # Allows kubectl/gcloud commands executed from the bastion to inspect and
      # manage Kubernetes resources in the GKE cluster.
      #
      # This is needed because the deployment script applies Kubernetes manifests
      # from the bastion against the private GKE control plane.
      "roles/container.developer"
    ]
  }
}

module "firewall" {
  # Use the Fabric firewall module to manage VPC firewall rules.
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/net-vpc-firewall?ref=v55.4.0"

  project_id = var.project_id
  network    = var.network_name

  # Disable Fabric's default firewall rules so this module only creates the
  # explicit rules we define below.
  #
  # This supports least privilege: no broad default ingress rules are created.
  default_rules_config = {
    disabled = true
  }

  ingress_rules = {
    allow-iap-ssh-to-bastion = {
      description = "Allow SSH to bastion only through IAP"

      # 35.235.240.0/20 is Google's Identity-Aware Proxy TCP forwarding range.
      # Allowing SSH only from this range means users cannot SSH directly from
      # arbitrary public IPs.
      source_ranges = ["35.235.240.0/20"]

      # Apply this SSH rule only to instances with the bastion network tag.
      targets = [local.bastion_network_tag]

      rules = [
        {
          # SSH uses TCP port 22.
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    }
  }
}

module "bastion_vm" {
  # Use the Fabric compute VM module to create the bastion host.
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/compute-vm?ref=v55.4.0"

  project_id = var.project_id
  zone       = var.zone
  name       = local.bastion_name

  # Small machine type is enough because the bastion is only used for admin
  # tasks such as gcloud/kubectl, not for running application workloads.
  machine_type = "e2-micro"

  boot_disk = {
    initialize_params = {
      # 10 GB is enough for the bastion OS and admin tooling.
      size = 10

      # Standard persistent disk is acceptable for a lightweight bastion.
      type = "pd-standard"
    }

    source = {
      # Ubuntu LTS image used for the bastion OS.
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interfaces = [
    {
      network    = var.network_self_link
      subnetwork = var.management_subnet_self_link

      # Do not assign an external/public IP address.
      #
      # The bastion is reached through IAP TCP forwarding instead of public SSH.
      nat = false
    }
  ]

  # Attach the network tag used by the firewall rule above.
  tags = [local.bastion_network_tag]

  metadata = {
    # Enable OS Login so SSH access is controlled by IAM instead of unmanaged
    # project/instance SSH keys.
    enable-oslogin = "TRUE"

    # Install required admin tools such as gcloud, kubectl, and the GKE auth
    # plugin when the VM starts.
    startup-script = file("${path.module}/startup.sh")
  }

  service_account = {
    # Attach the dedicated bastion service account.
    #
    # This avoids using the default Compute Engine service account and keeps
    # bastion permissions separate from other workloads.
    email = module.bastion_sa.email
  }

  shielded_config = {
    # Secure Boot helps protect the VM boot chain from tampering or untrusted bootable images.
    enable_secure_boot = true

    # vTPM supports measured boot and integrity validation.
    enable_vtpm = true

    # Integrity monitoring reports boot integrity events to Cloud Monitoring to monitor the predictibility of the boot process.
    enable_integrity_monitoring = true
  }
}