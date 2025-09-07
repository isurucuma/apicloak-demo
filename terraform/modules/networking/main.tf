# Networking Module for Gateway Solution
# This creates the VPC network where our APISIX gateway will run

# Main VPC Network
resource "google_compute_network" "vpc" {
  name                    = "${var.environment}-gateway-vpc"
  auto_create_subnetworks = false
  routing_mode           = "REGIONAL"
  description            = "VPC network for ${var.environment} gateway infrastructure"
}

# Subnet for GKE cluster
resource "google_compute_subnetwork" "gke_subnet" {
  name          = "${var.environment}-gke-subnet"
  ip_cidr_range = var.gke_subnet_cidr
  network       = google_compute_network.vpc.id
  region        = var.region
  description   = "Subnet for GKE cluster nodes"

  # Secondary IP ranges for Kubernetes pods and services
  secondary_ip_range {
    range_name    = "pods-range"
    ip_cidr_range = var.pods_cidr_range
  }

  secondary_ip_range {
    range_name    = "services-range"
    ip_cidr_range = var.services_cidr_range
  }

  # Enable private Google access for nodes to reach GCP APIs
  private_ip_google_access = true
}

# Cloud Router for NAT Gateway
resource "google_compute_router" "router" {
  name    = "${var.environment}-gateway-router"
  region  = var.region
  network = google_compute_network.vpc.id

  bgp {
    asn = 64514
  }
}

# NAT Gateway for outbound internet access from private nodes
resource "google_compute_router_nat" "nat" {
  name                               = "${var.environment}-gateway-nat"
  router                            = google_compute_router.router.name
  region                            = var.region
  nat_ip_allocate_option            = "AUTO_ONLY"
  source_subnetwork_ip_ranges_to_nat = "ALL_SUBNETWORKS_ALL_IP_RANGES"

  log_config {
    enable = true
    filter = "ERRORS_ONLY"
  }
}

# Firewall rule to allow internal communication
resource "google_compute_firewall" "allow_internal" {
  name    = "${var.environment}-allow-internal"
  network = google_compute_network.vpc.name
  
  allow {
    protocol = "tcp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "udp"
    ports    = ["0-65535"]
  }

  allow {
    protocol = "icmp"
  }

  source_ranges = [
    var.gke_subnet_cidr,
    var.pods_cidr_range,
    var.services_cidr_range
  ]
  
  description = "Allow internal communication within VPC"
}

# Firewall rule to allow health checks from Google Load Balancer
resource "google_compute_firewall" "allow_health_check" {
  name    = "${var.environment}-allow-health-check"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["80", "443", "8080", "9080"]
  }

  source_ranges = [
    "130.211.0.0/22",
    "35.191.0.0/16"
  ]

  target_tags = ["gke-node"]
  description = "Allow health checks from Google Cloud Load Balancer"
}

# Firewall rule to allow SSH access (for debugging, can be removed later)
resource "google_compute_firewall" "allow_ssh" {
  name    = "${var.environment}-allow-ssh"
  network = google_compute_network.vpc.name

  allow {
    protocol = "tcp"
    ports    = ["22"]
  }

  source_ranges = ["0.0.0.0/0"]  # Restrict this to your IP in production
  target_tags   = ["gke-node"]
  description   = "Allow SSH access for debugging"
}
