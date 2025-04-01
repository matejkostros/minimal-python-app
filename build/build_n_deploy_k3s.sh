#!/bin/bash
# Enhanced script for building, deploying and verifying k3s setup
set -eo pipefail

# Define color codes for better output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[0;33m'
NC='\033[0m' # No Color

# Function to print status messages
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
    exit 1
}

# Set KUBECONFIG to use k3s config file
export KUBECONFIG=~/.kube/k3s_config
log_info "Using KUBECONFIG=${KUBECONFIG}"

# Verify k3s is running
if ! sudo systemctl is-active --quiet k3s; then
    log_error "k3s service is not running. Starting it now..."
    sudo systemctl start k3s || log_error "Failed to start k3s service"
    sleep 5 # Give k3s time to initialize
fi
log_info "k3s service is running"

# Make sure the k3s config file exists and is accessible
if [ ! -f "${KUBECONFIG}" ]; then
    log_info "Creating k3s config file at ${KUBECONFIG}"
    mkdir -p $(dirname "${KUBECONFIG}")
    sudo cat /etc/rancher/k3s/k3s.yaml > "${KUBECONFIG}" || log_error "Failed to copy k3s config"
    sudo chown $(whoami): "${KUBECONFIG}"
    # Replace localhost with 127.0.0.1 to ensure network connectivity
    sed -i 's/server: https:\/\/localhost:/server: https:\/\/127.0.0.1:/g' "${KUBECONFIG}"
fi

# Test kubectl connectivity
log_info "Testing kubectl connectivity to k3s cluster..."
kubectl cluster-info || log_error "Failed to connect to k3s cluster"
kubectl get nodes || log_error "Failed to get nodes from k3s cluster"

# Build the Docker image
log_info "Building Docker image"
docker build -t minimal-python-app:latest . || log_error "Docker build failed"

# Save the Docker image to a tar file
log_info "Saving Docker image to tar file"
docker save minimal-python-app:latest -o minimal-python-app_latest.tar || log_error "Failed to save Docker image"

# Import the image into k3s containerd
log_info "Importing Docker image into k3s containerd"
sudo k3s ctr images import minimal-python-app_latest.tar || log_error "Failed to import image to k3s containerd"

# Apply the Kubernetes manifest
log_info "Deploying to k3s cluster"
kubectl apply -f kubernetes/deployment.yaml || log_error "Failed to apply Kubernetes manifest"

# Verify deployment status
log_info "Waiting for deployment to be ready..."
kubectl rollout status deployment/minimal-python-app --timeout=60s || log_warn "Deployment not ready within timeout"

# Get service details
log_info "Service details:"
kubectl get svc minimal-python-app

# Display pod status
log_info "Pod status:"
kubectl get pods -l app=minimal-python-app

# If we reach here, everything was successful
log_info "Deployment completed successfully!"
log_info "Use the following commands with the correct KUBECONFIG:"
echo -e "${YELLOW}export KUBECONFIG=~/.kube/k3s_config${NC}"
echo -e "${YELLOW}kubectl port-forward svc/minimal-python-app 8080:80${NC}"
echo -e "${YELLOW}# Then access http://localhost:8080 in your browser${NC}"