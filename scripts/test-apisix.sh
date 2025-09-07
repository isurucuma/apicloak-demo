#!/bin/bash

# Test APISIX Gateway Functionality
# This script tests basic APISIX functionality after deployment

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

# Get gateway IP from Terraform
get_gateway_ip() {
    cd terraform/environments/dev
    GATEWAY_IP=$(terraform output -raw gateway_ip 2>/dev/null || echo "")
    cd ../../..
    
    if [ -z "$GATEWAY_IP" ]; then
        echo -e "${RED}❌ Could not get gateway IP from Terraform${NC}"
        exit 1
    fi
    
    echo -e "${GREEN}✅ Gateway IP: $GATEWAY_IP${NC}"
}

# Wait for LoadBalancer to be ready
wait_for_loadbalancer() {
    echo -e "${YELLOW}⏳ Waiting for LoadBalancer to be ready...${NC}"
    
    for i in {1..30}; do
        if kubectl get svc -n apisix-system apisix-data-plane -o jsonpath='{.status.loadBalancer.ingress[0].ip}' 2>/dev/null | grep -q .; then
            echo -e "${GREEN}✅ LoadBalancer is ready${NC}"
            return 0
        fi
        echo "Waiting... ($i/30)"
        sleep 10
    done
    
    echo -e "${RED}❌ LoadBalancer not ready after 5 minutes${NC}"
    echo "Check service status: kubectl get svc -n apisix-system"
    exit 1
}

# Test basic APISIX response
test_apisix_basic() {
    echo -e "${YELLOW}🧪 Testing basic APISIX response...${NC}"
    
    response=$(curl -s -o /dev/null -w "%{http_code}" "http://$GATEWAY_IP" || echo "000")
    
    if [ "$response" = "404" ]; then
        echo -e "${GREEN}✅ APISIX is responding (404 is expected - no routes configured)${NC}"
    elif [ "$response" = "200" ]; then
        echo -e "${GREEN}✅ APISIX is responding${NC}"
    else
        echo -e "${RED}❌ APISIX not responding properly (HTTP $response)${NC}"
        echo "Try: curl -v http://$GATEWAY_IP"
        return 1
    fi
}

# Test APISIX Admin API
test_admin_api() {
    echo -e "${YELLOW}🔧 Testing APISIX Admin API...${NC}"
    
    # Try to access admin routes endpoint
    response=$(curl -s -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
        "http://$GATEWAY_IP:9180/apisix/admin/routes" || echo "failed")
    
    if echo "$response" | grep -q "node"; then
        echo -e "${GREEN}✅ Admin API is accessible${NC}"
        echo "Routes count: $(echo "$response" | jq -r '.total // 0' 2>/dev/null || echo "0")"
    else
        echo -e "${RED}❌ Admin API not accessible${NC}"
        echo "Response: $response"
        return 1
    fi
}

# Create a test route
create_test_route() {
    echo -e "${YELLOW}🛣️  Creating a test route...${NC}"
    
    # Create a simple route to httpbin.org for testing
    curl -s -X PUT "http://$GATEWAY_IP:9180/apisix/admin/routes/1" \
        -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" \
        -H "Content-Type: application/json" \
        -d '{
            "uri": "/test/*",
            "upstream": {
                "type": "roundrobin",
                "nodes": {
                    "httpbin.org:80": 1
                }
            }
        }' > /dev/null
    
    if [ $? -eq 0 ]; then
        echo -e "${GREEN}✅ Test route created: /test/* -> httpbin.org${NC}"
    else
        echo -e "${RED}❌ Failed to create test route${NC}"
        return 1
    fi
}

# Test the created route
test_route() {
    echo -e "${YELLOW}🌐 Testing the created route...${NC}"
    
    # Wait a moment for route to be active
    sleep 2
    
    # Test the route
    response=$(curl -s "http://$GATEWAY_IP/test/get" | jq -r '.url // "failed"' 2>/dev/null || echo "failed")
    
    if echo "$response" | grep -q "httpbin.org"; then
        echo -e "${GREEN}✅ Route is working! Response from: $response${NC}"
    else
        echo -e "${RED}❌ Route test failed${NC}"
        echo "Try manually: curl http://$GATEWAY_IP/test/get"
        return 1
    fi
}

# Show pod status
show_status() {
    echo -e "${YELLOW}📊 APISIX Pod Status:${NC}"
    kubectl get pods -n apisix-system
    echo
    echo -e "${YELLOW}📊 Service Status:${NC}"
    kubectl get svc -n apisix-system
}

# Cleanup test route
cleanup_test_route() {
    echo -e "${YELLOW}🧹 Cleaning up test route...${NC}"
    curl -s -X DELETE "http://$GATEWAY_IP:9180/apisix/admin/routes/1" \
        -H "X-API-KEY: edd1c9f034335f136f87ad84b625c8f1" > /dev/null
    echo -e "${GREEN}✅ Test route removed${NC}"
}

# Main test execution
main() {
    echo -e "${GREEN}🚀 Starting APISIX functionality tests...${NC}"
    echo
    
    get_gateway_ip
    wait_for_loadbalancer
    test_apisix_basic
    test_admin_api
    create_test_route
    test_route
    show_status
    
    echo
    echo -e "${GREEN}🎉 All tests passed! APISIX is working correctly.${NC}"
    echo
    echo -e "${YELLOW}Next steps:${NC}"
    echo "1. Access dashboard: kubectl port-forward -n apisix-system svc/apisix-dashboard 9000:9000"
    echo "2. Dashboard URL: http://localhost:9000"
    echo "3. Create more routes using Admin API or Dashboard"
    echo "4. Integrate with Keycloak for authentication"
    
    # Ask if user wants to cleanup test route
    echo
    read -p "Remove test route? (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        cleanup_test_route
    fi
}

# Check prerequisites
if ! command -v kubectl &> /dev/null; then
    echo -e "${RED}❌ kubectl is not installed${NC}"
    exit 1
fi

if ! command -v curl &> /dev/null; then
    echo -e "${RED}❌ curl is not installed${NC}"
    exit 1
fi

# Run main function
main "$@"
