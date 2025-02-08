resource "google_container_cluster" "gke" {
  name     = var.cluster_name
  location = var.region
  initial_node_count = var.node_count

  node_config {
    machine_type = var.node_machine_type
    disk_size_gb = 20
    disk_type    = "pd-standard"
    oauth_scopes = [
      "https://www.googleapis.com/auth/cloud-platform"
    ]
  }
}

data "google_client_config" "default" {}

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

resource "helm_release" "traefik" {
  name       = "traefik"
  repository = "https://helm.traefik.io/traefik"
  chart      = "traefik"
  namespace  = "traefik"

  set {
    name  = "service.type"
    value = "LoadBalancer"
  }
}

resource "helm_release" "cert_manager" {
  name       = "cert-manager"
  repository = "https://charts.jetstack.io"
  chart      = "cert-manager"
  namespace  = "cert-manager"

  set {
    name  = "installCRDs"
    value = "true"
  }
}

resource "kubernetes_manifest" "letsencrypt_issuer" {
  manifest = {
    apiVersion = "cert-manager.io/v1"
    kind       = "ClusterIssuer"
    metadata = {
      name = "letsencrypt-prod"
    }
    spec = {
      acme = {
        email  = var.email
        server = "https://acme-v02.api.letsencrypt.org/directory"
        privateKeySecretRef = {
          name = "letsencrypt-prod"
        }
        solvers = [{
          http01 = {
            ingress = {
              class = "traefik"
            }
          }
        }]
      }
    }
  }
}

resource "helm_release" "static_site_dev" {
  name       = "static-site-dev"
  chart      = "./helm-chart"
  namespace  = "dev"
  values     = [file("./helm-chart/values-dev.yaml")]
}

resource "helm_release" "static_site_prod" {
  name       = "static-site-prod"
  chart      = "./helm-chart"
  namespace  = "prod"
  values     = [file("./helm-chart/values-prod.yaml")]
}

resource "kubernetes_ingress_v1" "dev_ingress" {
  metadata {
    name      = "nginx-dev-ingress"
    namespace = "dev"
    annotations = {
      "cert-manager.io/cluster-issuer" = "letsencrypt-prod"
      "traefik.ingress.kubernetes.io/router.entrypoints" = "websecure"
    }
  }

  spec {
    ingress_class_name = "traefik"

    tls {
      hosts       = [var.domain_dev]
      secret_name = "tls-secret-dev"
    }

    rule {
      host = var.domain_dev
      http {
        path {
          path      = "/"
          path_type = "Prefix"

          backend {
            service {
              name = "nginx-dev-service"
              port {
                number = 80
              }
            }
          }
        }
      }
    }
  }
}