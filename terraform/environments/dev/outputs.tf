# Development Environment Outputs

output "cluster_connection_command" {
  description = "Command to connect to the GKE cluster"
  value       = module.gke.kubectl_config_command
}

output "gateway_ip" {
  description = "Static IP address for the gateway"
  value       = google_compute_global_address.gateway_ip.address
}

output "cluster_name" {
  description = "Name of the created GKE cluster"
  value       = module.gke.cluster_name
}

output "cluster_location" {
  description = "Location of the GKE cluster"
  value       = module.gke.cluster_location
}

output "vpc_name" {
  description = "Name of the created VPC"
  value       = module.networking.vpc_name
}

# Instructions for next steps
output "next_steps" {
  description = "Instructions for deploying APISIX"
  value = <<-EOT
    1. Connect to cluster: ${module.gke.kubectl_config_command}
    2. Verify connection: kubectl get nodes
    3. Deploy APISIX: cd ../../helm && helm install apisix ./charts/apisix
    4. Access APISIX at: http://${google_compute_global_address.gateway_ip.address}
  EOT
}
