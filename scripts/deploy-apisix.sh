#!/bin/bash

# Deploy APISIX Infrastructure and Application
# This script deploys the complete APISIX setup

set -e  # Exit on any error

echo "🚀 Deploying APISIX Gateway Infrastructure..."

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if required tools are installed
check_prerequisites() {
    echo "🔍 Checking prerequisites..."
    
    if ! command -v terraform &> /dev/null; then
        echo -e "${RED}❌ Terraform is not installed${NC}"
        exit 1
    fi
    
    if ! command -v helm &> /dev/null; then
        echo -e "${RED}❌ Helm is not installed${NC}"
        exit 1
    fi
    
    if ! command -v kubectl &> /dev/null; then
        echo -e "${RED}❌ kubectl is not installed${NC}"
        exit 1
    fi
    
    if ! command -v gcloud &> /dev/null; then
        echo -e "${RED}❌ gcloud CLI is not installed${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ All prerequisites are installed${NC}"
}

# Deploy infrastructure with Terraform
deploy_infrastructure() {
    echo -e "${YELLOW}📦 Deploying infrastructure with Terraform...${NC}"
    
    cd terraform/environments/dev
    
    # Check if terraform.tfvars exists
    if [ ! -f "terraform.tfvars" ]; then
        echo -e "${RED}❌ terraform.tfvars not found!${NC}"
        echo "Please copy terraform.tfvars.example to terraform.tfvars and update with your values"
        exit 1
    fi
    
    # Initialize Terraform
    terraform init
    
    # Plan the deployment
    echo -e "${YELLOW}🔍 Planning infrastructure changes...${NC}"
    terraform plan
    
    # Ask for confirmation
    read -p "Do you want to apply these changes? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        # Apply the changes
        terraform apply -auto-approve
        echo -e "${GREEN}✅ Infrastructure deployed successfully${NC}"
    else
        echo -e "${YELLOW}⏸️  Infrastructure deployment cancelled${NC}"
        exit 0
    fi
    
    cd ../../..
}

# Configure kubectl to connect to the cluster
configure_kubectl() {
    echo -e "${YELLOW}⚙️  Configuring kubectl...${NC}"
    
    # Get the cluster connection command from Terraform output
    cd terraform/environments/dev
    KUBECTL_CMD=$(terraform output -raw cluster_connection_command)
    cd ../../..
    
    # Execute the command
    eval $KUBECTL_CMD
    
    # Verify connection
    echo -e "${YELLOW}🔍 Verifying cluster connection...${NC}"
    kubectl get nodes
    
    echo -e "${GREEN}✅ kubectl configured successfully${NC}"
}

# Deploy APISIX using Helm
deploy_apisix() {
    echo -e "${YELLOW}🌐 Deploying APISIX Gateway with Bitnami chart...${NC}"
    
    # Get the static IP from Terraform for LoadBalancer
    cd terraform/environments/dev
    GATEWAY_IP=$(terraform output -raw gateway_ip)
    cd ../../..
    
    cd helm/charts/apisix
    
    # Ensure Bitnami repository is added and updated
    helm repo add bitnami https://charts.bitnami.com/bitnami
    helm repo update
    
    # Update dependencies (etcd, common charts)
    helm dependency update
    
    # Install APISIX using Bitnami chart with our custom values
    helm upgrade --install apisix . \
        --namespace apisix-system \
        --create-namespace \
        --values values-dev.yaml \
        --set dataPlane.service.loadBalancerIP="$GATEWAY_IP" \
        --wait \
        --timeout=15m
    
    echo -e "${GREEN}✅ APISIX deployed successfully using Bitnami chart${NC}"
    
    cd ../../..
}

# Display connection information
show_connection_info() {
    echo -e "${YELLOW}📋 Getting connection information...${NC}"
    
    cd terraform/environments/dev
    GATEWAY_IP=$(terraform output -raw gateway_ip)
    cd ../../..
    
    echo
    echo -e "${GREEN}🎉 APISIX Gateway is now deployed using Bitnami chart!${NC}"
    echo
    echo -e "${YELLOW}Connection Information:${NC}"
    echo "Gateway IP: http://$GATEWAY_IP"
    echo "Admin API: http://$GATEWAY_IP:9180"
    echo "Dashboard: Access via port-forward (see commands below)"
    echo
    echo -e "${YELLOW}Useful Commands:${NC}"
    echo "Check APISIX pods: kubectl get pods -n apisix-system"
    echo "Check services: kubectl get services -n apisix-system"
    echo "View APISIX logs: kubectl logs -n apisix-system -l app.kubernetes.io/name=apisix,app.kubernetes.io/component=data-plane"
    echo "View Control Plane logs: kubectl logs -n apisix-system -l app.kubernetes.io/name=apisix,app.kubernetes.io/component=control-plane"
    echo "Access Dashboard: kubectl port-forward -n apisix-system svc/apisix-dashboard 9000:9000"
    echo
    echo -e "${YELLOW}Test Commands:${NC}"
    echo "Test APISIX: curl http://$GATEWAY_IP"
    echo "Test Admin API: curl http://$GATEWAY_IP:9180/apisix/admin/routes -H 'X-API-KEY: edd1c9f034335f136f87ad84b625c8f1'"
    echo
    echo -e "${YELLOW}Next Steps:${NC}"
    echo "1. Wait for the LoadBalancer to be ready (may take a few minutes)"
    echo "2. Check service status: kubectl get svc -n apisix-system"
    echo "3. Create your first route using the Admin API or Dashboard"
    echo "4. Test routing functionality"
}

# Main execution
main() {
    echo "🚀 Starting APISIX Gateway deployment..."
    echo
    
    check_prerequisites
    deploy_infrastructure
    configure_kubectl
    deploy_apisix
    show_connection_info
    
    echo
    echo -e "${GREEN}🎉 Deployment completed successfully!${NC}"
}

# Run the main function
main "$@"
