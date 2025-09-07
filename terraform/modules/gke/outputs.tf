# GKE Module Outputs

output "cluster_name" {
  description = "Name of the GKE cluster"
  value       = google_container_cluster.primary.name
}

output "cluster_endpoint" {
  description = "Endpoint of the GKE cluster"
  value       = google_container_cluster.primary.endpoint
  sensitive   = true
}

output "cluster_location" {
  description = "Location of the GKE cluster"
  value       = google_container_cluster.primary.location
}

output "cluster_ca_certificate" {
  description = "CA certificate of the GKE cluster"
  value       = google_container_cluster.primary.master_auth.0.cluster_ca_certificate
  sensitive   = true
}

output "service_account_email" {
  description = "Email of the GKE service account"
  value       = google_service_account.gke_sa.email
}

# Commands to connect to the cluster
output "kubectl_config_command" {
  description = "Command to configure kubectl"
  value       = "gcloud container clusters get-credentials ${google_container_cluster.primary.name} --region=${google_container_cluster.primary.location} --project=${var.project_id}"
}

output "node_pool_name" {
  description = "Name of the primary node pool"
  value       = google_container_node_pool.primary_nodes.name
}

output "node_count" {
  description = "Number of nodes in the cluster"
  value       = google_container_node_pool.primary_nodes.node_count
}

output "machine_type" {
  description = "Machine type used for nodes"
  value       = google_container_node_pool.primary_nodes.node_config[0].machine_type
}
