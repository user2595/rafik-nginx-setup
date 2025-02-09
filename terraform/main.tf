# GKE-Cluster
resource "google_container_cluster" "primary" {
  name     = var.cluster_name
  location = var.region

  remove_default_node_pool = true
  initial_node_count       = 1

  network    = google_compute_network.vpc.name
  subnetwork = google_compute_subnetwork.subnet.name
}

resource "google_container_node_pool" "primary_nodes" {
  name       = "default-pool"
  location   = var.region
  cluster    = google_container_cluster.primary.name
  node_count = 1

  node_config {
    preemptible  = true
    machine_type = "e2-small"
    disk_size_gb = 20

    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }

  autoscaling {
    min_node_count = 1
    max_node_count = 3
  }
}

# VPC-Netzwerk
resource "google_compute_network" "vpc" {
  name                    = "${var.project_id}-vpc"
  auto_create_subnetworks = false
}

resource "google_compute_subnetwork" "subnet" {
  name          = "${var.project_id}-subnet"
  region        = var.region
  network       = google_compute_network.vpc.name
  ip_cidr_range = "10.0.0.0/24"
}

# Statische IP-Adresse
resource "google_compute_address" "ingress_ip" {
  name   = "ingress-ip"
  region = var.region
}

# Helm-Releases
resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://helm.traefik.io/traefik"
  chart      = "traefik"
  namespace  = "traefik"

  values = [
    file("./traefik/values.yaml")
  ]

  depends_on = [google_container_cluster.primary]
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"

  values = [
    file("./cert-manager/values.yaml")
  ]

  depends_on = [google_container_cluster.primary]
}

# Kubernetes-Ressourcen
resource "kubernetes_namespace" "dev" {
  metadata {
    name = "dev"
  }
}

resource "kubernetes_namespace" "prod" {
  metadata {
    name = "prod"
  }
}

resource "helm_release" "static_site_dev" {
  name      = "static-site-dev"
  chart     = "./static-site"
  namespace = kubernetes_namespace.dev.metadata[0].name

  values = [
    file("./static-site/values-dev.yaml")
  ]

  depends_on = [helm_release.traefik, helm_release.cert_manager]
}

resource "helm_release" "static_site_prod" {
  name      = "static-site-prod"
  chart     = "./static-site"
  namespace = kubernetes_namespace.prod.metadata[0].name

  values = [
    file("./static-site/values-prod.yaml")
  ]

  depends_on = [helm_release.traefik, helm_release.cert_manager]
}

# Google Cloud Uptime Checks
resource "google_monitoring_uptime_check_config" "dev" {
  display_name = "Dev Uptime Check"
  timeout      = "10s"

  http_check {
    path         = "/"
    port         = "443"
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.domain_dev
    }
  }
}

resource "google_monitoring_uptime_check_config" "prod" {
  display_name = "Prod Uptime Check"
  timeout      = "10s"

  http_check {
    path         = "/"
    port         = "443"
    use_ssl      = true
    validate_ssl = true
  }

  monitored_resource {
    type = "uptime_url"
    labels = {
      project_id = var.project_id
      host       = var.domain_prod
    }
  }
}

# Benachrichtigungskanal
resource "google_monitoring_notification_channel" "email" {
  display_name = "Uptime Alert"
  type         = "email"

  labels = {
    email_address = var.email
  }
}