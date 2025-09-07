# Networking Module Outputs

output "vpc_name" {
  description = "Name of the VPC network"
  value       = google_compute_network.vpc.name
}

output "vpc_id" {
  description = "ID of the VPC network"
  value       = google_compute_network.vpc.id
}

output "gke_subnet_name" {
  description = "Name of the GKE subnet"
  value       = google_compute_subnetwork.gke_subnet.name
}

output "gke_subnet_id" {
  description = "ID of the GKE subnet"
  value       = google_compute_subnetwork.gke_subnet.id
}

output "pods_range_name" {
  description = "Name of the pods IP range"
  value       = "pods-range"
}

output "services_range_name" {
  description = "Name of the services IP range"
  value       = "services-range"
}
