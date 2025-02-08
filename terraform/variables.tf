
variable "project_id" {
  description = "Google Cloud Project ID"
  type        = string
}

variable "region" {
  description = "GKE Cluster Region"
  type        = string
  default     = "europe-west3"
}

variable "cluster_name" {
  description = "Name of the GKE Cluster"
  type        = string
  default     = "gke-static-site"
}

variable "node_count" {
  description = "Number of GKE Nodes"
  type        = number
  default     = 3
}

variable "node_machine_type" {
  description = "Machine Type for GKE Nodes"
  type        = string
  default     = "e2-small"
}

variable "domain_dev" {
  description = "Domain name for dev environment"
  type        = string
  default     = "dev.kub.eulernest.eu"
}

variable "domain_prod" {
  description = "Domain name for prod environment"
  type        = string
  default     = "prod.kub.eulernest.eu"
}

variable "email" {
  description = "Email for Let's Encrypt Certificates"
  type        = string
}