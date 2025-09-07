# APISIX Gateway Setup Guide

## Prerequisites

Before you begin, ensure you have the following installed:

1. **Google Cloud CLI (gcloud)**

   ```bash
   # Install gcloud CLI
   curl https://sdk.cloud.google.com | bash
   exec -l $SHELL
   gcloud init
   ```

2. **Terraform**

   ```bash
   # Install Terraform
   wget https://releases.hashicorp.com/terraform/1.6.6/terraform_1.6.6_linux_amd64.zip
   unzip terraform_1.6.6_linux_amd64.zip
   sudo mv terraform /usr/local/bin/
   ```

3. **kubectl**

   ```bash
   # Install kubectl
   curl -LO "https://dl.k8s.io/release/$(curl -L -s https://dl.k8s.io/release/stable.txt)/bin/linux/amd64/kubectl"
   chmod +x kubectl
   sudo mv kubectl /usr/local/bin/
   ```

4. **Helm**
   ```bash
   # Install Helm
   curl https://get.helm.sh/helm-v3.13.0-linux-amd64.tar.gz | tar -xzO linux-amd64/helm > helm
   chmod +x helm
   sudo mv helm /usr/local/bin/
   ```

## Google Cloud Setup

1. **Create a new GCP Project** (or use existing):

   ```bash
   # Create project
   gcloud projects create YOUR_PROJECT_ID

   # Set as default
   gcloud config set project YOUR_PROJECT_ID

   # Enable billing (required for GKE)
   gcloud beta billing projects link YOUR_PROJECT_ID --billing-account=YOUR_BILLING_ACCOUNT_ID
   ```

2. **Authenticate with Google Cloud**:
   ```bash
   gcloud auth login
   gcloud auth application-default login
   ```

## Configuration

1. **Configure Terraform variables**:

   ```bash
   cd terraform/environments/dev
   cp terraform.tfvars.example terraform.tfvars
   ```

2. **Edit terraform.tfvars** with your project details:
   ```hcl
   project_id = "your-actual-project-id"
   region     = "us-central1"  # or your preferred region
   environment = "dev"
   ```

## Deployment

### Option 1: One-Command Deployment (Recommended)

```bash
./scripts/deploy-apisix.sh
```

### Option 2: Manual Step-by-Step Deployment

1. **Deploy Infrastructure**:

   ```bash
   cd terraform/environments/dev
   terraform init
   terraform plan
   terraform apply
   ```

2. **Connect to Kubernetes**:

   ```bash
   # Get the connection command from Terraform output
   terraform output cluster_connection_command

   # Run the command (example):
   gcloud container clusters get-credentials dev-gateway-cluster --region=us-central1 --project=your-project-id
   ```

3. **Deploy APISIX**:

   ```bash
   cd ../../../helm/charts/apisix
   helm repo add bitnami https://charts.bitnami.com/bitnami
   helm repo update
   helm dependency update

   # Get the static IP from Terraform
   cd ../../../terraform/environments/dev
   GATEWAY_IP=$(terraform output -raw gateway_ip)
   cd ../../../helm/charts/apisix

   # Deploy APISIX with Bitnami chart
   helm upgrade --install apisix . \
     --namespace apisix-system \
     --create-namespace \
     --values values-dev.yaml \
     --set dataPlane.service.loadBalancerIP="$GATEWAY_IP" \
     --wait
   ```

## Verification & Testing

1. **Check if everything is running**:

   ```bash
   # Check cluster nodes
   kubectl get nodes

   # Check APISIX pods
   kubectl get pods -n apisix-system

   # Check services
   kubectl get services -n apisix-system
   ```

2. **Get Gateway IP**:

   ```bash
   cd terraform/environments/dev
   terraform output gateway_ip
   ```

3. **Run comprehensive tests**:

   ```bash
   # Run our automated test suite
   ./scripts/test-apisix.sh
   ```

4. **Manual testing**:

   ```bash
   # Replace with your actual gateway IP
   GATEWAY_IP=$(cd terraform/environments/dev && terraform output -raw gateway_ip)

   # Test basic connectivity
   curl http://$GATEWAY_IP

   # Test admin API
   curl http://$GATEWAY_IP:9180/apisix/admin/routes \
     -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1'

   # Access dashboard via port-forward
   kubectl port-forward -n apisix-system svc/apisix-dashboard 9000:9000
   # Then visit: http://localhost:9000
   ```

## What Gets Created

### Infrastructure (Terraform):

- **GKE Standard Cluster**: 2-node Kubernetes cluster with custom node pool
- **VPC Network**: Private network with subnets
- **Firewall Rules**: Security rules for cluster communication
- **Static IP**: External IP address for load balancer
- **Service Accounts**: IAM for secure access

### Applications (Helm):

- **APISIX Gateway**: API gateway for routing traffic (Bitnami chart)
- **APISIX Control Plane**: Admin API for managing APISIX
- **APISIX Dashboard**: Web UI for managing APISIX
- **etcd**: Data store for APISIX configuration (embedded in Bitnami chart)

## Cost Estimation (with $300 credits)

**Daily costs (approximate):**

- GKE Standard (2 nodes): $2-4/day (e2-standard-2 instances)
- Load Balancer: $0.75/day
- Static IP: $0.12/day
- **Total: ~$2-4/day**

**Your $300 credit should last 75-150 days** for development!

## Cleanup

To avoid charges when not using:

```bash
cd terraform/environments/dev
terraform destroy
```

## Troubleshooting

### Common Issues:

1. **"API not enabled" error**:

   ```bash
   gcloud services enable container.googleapis.com compute.googleapis.com
   ```

2. **Permission denied**:

   ```bash
   gcloud auth application-default login
   ```

3. **Cluster connection issues**:

   ```bash
   gcloud container clusters get-credentials CLUSTER_NAME --region=REGION --project=PROJECT_ID
   ```

4. **APISIX pods not starting**:

   ```bash
   kubectl describe pods -n apisix-system
   kubectl logs -n apisix-system -l app.kubernetes.io/name=apisix,app.kubernetes.io/component=data-plane
   kubectl logs -n apisix-system -l app.kubernetes.io/name=apisix,app.kubernetes.io/component=control-plane
   ```

5. **Access Dashboard**:
   ```bash
   # Port-forward to access dashboard locally
   kubectl port-forward -n apisix-system svc/apisix-dashboard 9000:9000
   # Then access: http://localhost:9000
   ```

## Next Steps

Once APISIX is running successfully:

1. **Test basic routing**: Create your first route
2. **Add Keycloak**: Integrate authentication
3. **Set up monitoring**: Add Prometheus and Grafana
4. **Configure logging**: Set up ELK stack

## Support

If you encounter issues:

1. Check the troubleshooting section above
2. Review logs: `kubectl logs -n apisix-system`
3. Verify all prerequisites are installed
4. Ensure your GCP project has billing enabled
