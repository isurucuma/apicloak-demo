# Networking Module Variables

variable "environment" {
  description = "Environment name (dev, staging, prod)"
  type        = string
}

variable "region" {
  description = "GCP region for resources"
  type        = string
  default     = "us-central1"
}

variable "gke_subnet_cidr" {
  description = "CIDR range for GKE subnet"
  type        = string
  default     = "10.0.1.0/24"
}

variable "pods_cidr_range" {
  description = "CIDR range for Kubernetes pods"
  type        = string
  default     = "10.1.0.0/16"
}

variable "services_cidr_range" {
  description = "CIDR range for Kubernetes services"
  type        = string
  default     = "10.2.0.0/16"
}
