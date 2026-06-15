output "id" {
  description = "Redis Cluster resource ID"
  value       = google_redis_cluster.redis.id
}

output "name" {
  description = "Redis Cluster name"
  value       = google_redis_cluster.redis.name
}

output "psc_subnet_name" {
  description = "Private Service Connect subnet name"
  value       = google_compute_subnetwork.psc.name
}

output "discovery_endpoints" {
  description = "Redis Cluster discovery endpoints"
  value       = google_redis_cluster.redis.discovery_endpoints
}

output "host" {
  description = "Redis discovery endpoint address"
  value       = try(google_redis_cluster.redis.discovery_endpoints[0].address, null)
}

output "port" {
  description = "Redis discovery endpoint port"
  value       = try(google_redis_cluster.redis.discovery_endpoints[0].port, null)
}