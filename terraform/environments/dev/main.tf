# Development Environment - Main Configuration
# This file brings together all modules to create the APISIX infrastructure

terraform {
  required_version = ">= 1.5"

  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 5.0"
    }
  }

  # Backend configuration for state storage
  # Uncomment and configure when ready to use remote state
  # backend "gcs" {
  #   bucket = "your-terraform-state-bucket"
  #   prefix = "gateway/dev"
  # }
}

# Configure the Google Cloud Provider
provider "google" {
  project = var.project_id
  region  = var.region
}

# Enable required APIs
resource "google_project_service" "required_apis" {
  for_each = toset([
    "container.googleapis.com",
    "compute.googleapis.com",
    "servicenetworking.googleapis.com",
    "cloudresourcemanager.googleapis.com"
  ])

  service = each.value
  project = var.project_id

  disable_on_destroy = false
}

# Create networking infrastructure
module "networking" {
  source = "../../modules/networking"

  environment = var.environment
  region      = var.region

  depends_on = [google_project_service.required_apis]
}

# Create GKE cluster
module "gke" {
  source = "../../modules/gke"

  environment         = var.environment
  region              = var.region
  zone                = var.zone
  project_id          = var.project_id
  vpc_name            = module.networking.vpc_name
  subnet_name         = module.networking.gke_subnet_name
  pods_range_name     = module.networking.pods_range_name
  services_range_name = module.networking.services_range_name

  depends_on = [module.networking]
}

# Reserve static IP for load balancer (for APISIX external access)
resource "google_compute_global_address" "gateway_ip" {
  name        = "${var.environment}-gateway-ip"
  description = "Static IP for APISIX gateway load balancer"
}
