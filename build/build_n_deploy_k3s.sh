#!/bin/bash
# Enhanced script for building, deploying and verifying k3s setup with versioning
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

# Version file path - this will store our current version
VERSION_FILE=".version"

# Function to get the current version
get_current_version() {
    if [ -f "$VERSION_FILE" ]; then
        cat "$VERSION_FILE"
    else
        echo "1.0.0"  # Default starting version if no version file exists
    fi
}

# Function to increment the patch version
increment_patch_version() {
    local version=$1
    local major=$(echo $version | cut -d. -f1)
    local minor=$(echo $version | cut -d. -f2)
    local patch=$(echo $version | cut -d. -f3)
    local new_patch=$((patch + 1))
    echo "$major.$minor.$new_patch"
}

# Function to update the version file
update_version_file() {
    echo "$1" > "$VERSION_FILE"
    log_info "Updated version to $1"
}

# Parse command line arguments
VERSION_FLAG=false
BUMP_VERSION=false
VERSION=""

while [[ $# -gt 0 ]]; do
    key="$1"
    case $key in
        --version|-v)
            VERSION_FLAG=true
            if [[ "$2" == "bump" ]]; then
                BUMP_VERSION=true
                shift
            elif [[ "$2" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
                VERSION="$2"
                shift
            elif [[ "$2" == --* || "$2" == -* || -z "$2" ]]; then
                BUMP_VERSION=true
            else
                log_error "Invalid version format. Use: x.y.z or 'bump'"
            fi
            shift
            ;;
        *)
            # Unknown option
            log_warn "Unknown option: $1"
            shift
            ;;
    esac
done

# Determine the version to use
CURRENT_VERSION=$(get_current_version)

if [ "$VERSION_FLAG" = true ]; then
    if [ "$BUMP_VERSION" = true ]; then
        # Increment the patch version
        NEW_VERSION=$(increment_patch_version "$CURRENT_VERSION")
        update_version_file "$NEW_VERSION"
    elif [ -n "$VERSION" ]; then
        # Use the specified version
        NEW_VERSION="$VERSION"
        update_version_file "$NEW_VERSION"
    else
        # Just for safety, should not hit this due to argument parsing
        NEW_VERSION=$(increment_patch_version "$CURRENT_VERSION")
        update_version_file "$NEW_VERSION"
    fi
else
    # No version flag provided, use current version
    NEW_VERSION="$CURRENT_VERSION"
    log_info "Using current version: $NEW_VERSION"
fi

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

# Build the Docker image with version tag
log_info "Building Docker image with version: $NEW_VERSION"
docker build -t minimal-python-app:${NEW_VERSION} . || log_error "Docker build failed"

# Also tag as latest for convenience
log_info "Also tagging as latest"
docker tag minimal-python-app:${NEW_VERSION} minimal-python-app:latest

# Save the Docker image to a tar file
log_info "Saving Docker image to tar file"
docker save minimal-python-app:${NEW_VERSION} -o minimal-python-app_${NEW_VERSION}.tar || log_error "Failed to save Docker image"

# Import the image into k3s containerd
log_info "Importing Docker image into k3s containerd"
sudo k3s ctr images import minimal-python-app_${NEW_VERSION}.tar || log_error "Failed to import image to k3s containerd"

# Update the deployment YAML with the current version if needed
# This uses sed to replace the image tag in the deployment YAML
log_info "Updating deployment YAML with current version"
sed -i "s|image: docker.io/library/minimal-python-app:latest|image: docker.io/library/minimal-python-app:${NEW_VERSION}|g" kubernetes/deployment.yaml

# Apply the Kubernetes manifest
log_info "Deploying to k3s cluster"
kubectl apply -f kubernetes/ || log_error "Failed to apply Kubernetes manifest"

# Verify deployment status
log_info "Waiting for deployment to be ready..."
kubectl rollout status deployment/minimal-python-app --timeout=60s || log_warn "Deployment not ready within timeout"

# Get service details
log_info "Service details:"
kubectl get svc minimal-python-app

# Display pod status
log_info "Pod status:"
kubectl get pods -l app=minimal-python-app

# Reset deployment YAML back to latest for git repository (optional, comment out if you want to keep the version in the YAML)
# sed -i "s|image: docker.io/library/minimal-python-app:${NEW_VERSION}|image: docker.io/library/minimal-python-app:latest|g" kubernetes/deployment.yaml

# If we reach here, everything was successful
log_info "Deployment completed successfully with version ${NEW_VERSION}!"
log_info "Use the following commands with the correct KUBECONFIG:"
KUBERNETES_NODE_IP=$(kubectl get nodes -o jsonpath='{range .items[*]}{.status.addresses[?(@.type=="InternalIP")].address}{"\n"}{end}')
SERVICE_NODE_PORT=$(yq '.spec.ports[] | select(.nodePort != null) | .nodePort' kubernetes/deployment.yaml)
echo -e "${YELLOW}export KUBECONFIG=~/.kube/k3s_config${NC}"
echo -e "${YELLOW}# Then access http://${KUBERNETES_NODE_IP}:${SERVICE_NODE_PORT} in your browser${NC}"