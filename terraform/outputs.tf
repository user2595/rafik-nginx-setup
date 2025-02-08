output "gke_cluster_endpoint" {
  description = "GKE Cluster API Endpoint"
  value       = google_container_cluster.gke.endpoint
}

output "traefik_loadbalancer_ip" {
  description = "External IP of Traefik LoadBalancer"
  value       = helm_release.traefik.metadata[0].name
}

output "dev_url" {
  description = "Dev environment URL"
  value       = "https://${var.domain_dev}"
}

output "prod_url" {
  description = "Prod environment URL"
  value       = "https://${var.domain_prod}"
}