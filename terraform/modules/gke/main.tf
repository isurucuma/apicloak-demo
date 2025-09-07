# GKE Module for Gateway Solution
# This creates a minimal GKE Autopilot cluster for running APISIX

# Service account for GKE cluster
resource "google_service_account" "gke_sa" {
  account_id   = "${var.environment}-gke-sa"
  display_name = "GKE Service Account for ${var.environment}"
  description  = "Service account for GKE cluster nodes"
}

# IAM bindings for GKE service account
resource "google_project_iam_member" "gke_sa_logging" {
  project = var.project_id
  role    = "roles/logging.logWriter"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

resource "google_project_iam_member" "gke_sa_monitoring" {
  project = var.project_id
  role    = "roles/monitoring.metricWriter"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

resource "google_project_iam_member" "gke_sa_monitoring_viewer" {
  project = var.project_id
  role    = "roles/monitoring.viewer"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

resource "google_project_iam_member" "gke_sa_resource_metadata" {
  project = var.project_id
  role    = "roles/stackdriver.resourceMetadata.writer"
  member  = "serviceAccount:${google_service_account.gke_sa.email}"
}

# GKE Standard Cluster (2-node setup)
resource "google_container_cluster" "primary" {
  name     = "${var.environment}-gateway-cluster"
  location = var.zone

  # Disable Autopilot for standard cluster
  # enable_autopilot = false

  # # Remove default node pool (we'll create a custom one)
  remove_default_node_pool = true
  initial_node_count       = 1

  # Network configuration
  network    = var.vpc_name
  subnetwork = var.subnet_name

  # IP allocation for pods and services
  ip_allocation_policy {
    cluster_secondary_range_name  = var.pods_range_name
    services_secondary_range_name = var.services_range_name
  }

  # Private cluster configuration
  private_cluster_config {
    enable_private_nodes    = true
    enable_private_endpoint = false
    master_ipv4_cidr_block  = "172.16.0.0/28"
  }

  # Master authorized networks (who can access Kubernetes API)
  master_authorized_networks_config {
    cidr_blocks {
      cidr_block   = "0.0.0.0/0" # Restrict this in production
      display_name = "All networks"
    }
  }

  # Release channel for automatic updates
  release_channel {
    channel = "REGULAR"
  }

  # # Enable network policy
  network_policy {
    enabled  = true
    provider = "CALICO"
  }

  # Workload Identity for secure pod-to-GCP authentication
  workload_identity_config {
    workload_pool = "${var.project_id}.svc.id.goog"
  }

  # Basic maintenance window (during off-peak hours)
  maintenance_policy {
    daily_maintenance_window {
      start_time = "03:00" # 3 AM UTC
    }
  }

  # Enable basic cluster features
  addons_config {
    horizontal_pod_autoscaling {
      disabled = false
    }
    http_load_balancing {
      disabled = false
    }
    network_policy_config {
      disabled = false
    }
  }

  # Resource labels for organization
  resource_labels = {
    environment = var.environment
    component   = "gateway"
    managed-by  = "terraform"
  }

  description = "GKE Standard cluster for ${var.environment} gateway infrastructure"
}

# Custom Node Pool with 3 nodes
resource "google_container_node_pool" "primary_nodes" {
  name     = "${var.environment}-gateway-nodes"
  location = var.zone
  cluster  = google_container_cluster.primary.name

  # Number of nodes (2 for your requirement)
  node_count = 2

  # Node configuration
  node_config {
    # Use cost-effective machine type
    machine_type = "n1-standard-1" # 2 vCPUs, 8GB RAM
    disk_size_gb = 20
    disk_type    = "pd-standard"

    # Use the service account we created
    service_account = google_service_account.gke_sa.email

    # OAuth scopes for GCP API access
    oauth_scopes = [
      "https://www.googleapis.com/auth/logging.write",
      "https://www.googleapis.com/auth/monitoring",
      "https://www.googleapis.com/auth/devstorage.read_only"
    ]

    # Enable preemptible instances for cost savings (optional)
    preemptible = true

    # Node labels
    labels = {
      environment = var.environment
      node-type   = "gateway-worker"
    }

    # Node tags for firewall rules
    tags = ["gke-node", "${var.environment}-gke-node"]

    # Workload Identity configuration
    workload_metadata_config {
      mode = "GKE_METADATA"
    }

    # Security configuration
    shielded_instance_config {
      enable_secure_boot          = true
      enable_integrity_monitoring = true
    }
    metadata = {
      disable-legacy-endpoints = "true"
    }
  }

  # # Autoscaling configuration (optional - can scale from 2 to 2 nodes if needed)
  # autoscaling {
  #   min_node_count = 2
  #   max_node_count = 2
  # }

  # # Upgrade settings
  # upgrade_settings {
  #   max_surge       = 1
  #   max_unavailable = 0
  # }

  # # Node management
  # management {
  #   auto_repair  = true
  #   auto_upgrade = true
  # }
}

# Wait for cluster to be ready before outputting credentials
resource "time_sleep" "wait_for_cluster" {
  depends_on      = [google_container_cluster.primary]
  create_duration = "30s"
}
