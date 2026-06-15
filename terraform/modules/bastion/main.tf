locals {
  bastion_name        = "${var.name_prefix}-bastion"
  bastion_sa_name     = "${var.name_prefix}-bastion"
  bastion_network_tag = "${var.name_prefix}-bastion-ssh"
}

module "bastion_sa" {
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/iam-service-account?ref=v55.4.0"

  project_id   = var.project_id
  name         = local.bastion_sa_name
  display_name = "Bastion VM service account"

  iam_project_roles = {
    "${var.project_id}" = [
      "roles/logging.logWriter",
      "roles/monitoring.metricWriter",
      "roles/container.developer"
    ]
  }
}

module "firewall" {
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/net-vpc-firewall?ref=v55.4.0"

  project_id = var.project_id
  network    = var.network_name

  default_rules_config = {
    disabled = true
  }

  ingress_rules = {
    allow-iap-ssh-to-bastion = {
      description   = "Allow SSH to bastion only through IAP"
      source_ranges = ["35.235.240.0/20"]
      targets       = [local.bastion_network_tag]

      rules = [
        {
          protocol = "tcp"
          ports    = ["22"]
        }
      ]
    }
  }
}

module "bastion_vm" {
  source = "git::https://github.com/GoogleCloudPlatform/cloud-foundation-fabric.git//modules/compute-vm?ref=v55.4.0"

  project_id   = var.project_id
  zone         = var.zone
  name         = local.bastion_name
  machine_type = "e2-micro"

  boot_disk = {
    initialize_params = {
      size = 10
      type = "pd-standard"
    }

    source = {
      image = "ubuntu-os-cloud/ubuntu-2204-lts"
    }
  }

  network_interfaces = [
    {
      network    = var.network_self_link
      subnetwork = var.management_subnet_self_link
      nat        = false
    }
  ]

  tags = [local.bastion_network_tag]

  metadata = {
    enable-oslogin = "TRUE"
    startup-script = file("${path.module}/startup.sh")
  }

  service_account = {
    email = module.bastion_sa.email
  }

  shielded_config = {
    enable_secure_boot          = true
    enable_vtpm                 = true
    enable_integrity_monitoring = true
  }
}