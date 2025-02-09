output "gke_cluster_endpoint" {
  description = "GKE Cluster API Endpoint"
  value       = google_container_cluster.primary.endpoint
}

output "traefik_loadbalancer_ip" {
  description = "External IP of Traefik LoadBalancer"
  value       = data.kubernetes_service.traefik.status.0.load_balancer.0.ingress.0.ip
}

output "dev_url" {
  description = "Dev environment URL"
  value       = "https://${var.domain_dev}"
}

output "prod_url" {
  description = "Prod environment URL"
  value       = "https://${var.domain_prod}"
}

output "ingress_ip" {
  description = "Static IP address for Ingress"
  value       = google_compute_address.ingress_ip.address
}

data "kubernetes_service" "traefik" {
  metadata {
    name      = "traefik"
    namespace = "traefik"
  }
  depends_on = [helm_release.traefik]
}
