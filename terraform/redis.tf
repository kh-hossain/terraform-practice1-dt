module "redis" {
  source = "./modules/redis"

  project_id = var.project_id
  region     = var.region
  name       = "${local.name_prefix}-redis"
  network_id = "projects/${var.project_id}/global/networks/${module.network.network_name}"

  psc_subnet_cidr = var.redis_psc_subnet_cidr

  shard_count   = var.redis_shard_count
  replica_count = var.redis_replica_count

  labels = {
    component = "redis"
  }
}