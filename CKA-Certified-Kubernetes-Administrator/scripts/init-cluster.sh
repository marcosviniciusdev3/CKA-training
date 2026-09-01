#!/bin/bash
# CKA practice cluster — creates a local Kubernetes cluster with kind.
# Requires: Docker (running), kubectl, curl.
# 
# Usage:
#   ./scripts/init-cluster.sh                    # Create cluster named 'cka-practice'
#   CLUSTER_NAME=my-lab ./scripts/init-cluster.sh # Create with custom name
#   ./scripts/init-cluster.sh --recreate         # Delete and recreate cluster
#   ./scripts/init-cluster.sh --help             # Show help
#
# After creation, run: source ./scripts/exam-setup.sh

set -euo pipefail

CLUSTER_NAME="${CLUSTER_NAME:-cka-practice}"
KIND_VERSION="${KIND_VERSION:-v0.31.0}"
KUBE_VERSION="${KUBE_VERSION:-v1.35.1}"  # v1.35+ for native sidecar exercises
INSTALL_DIR="${INSTALL_DIR:-$HOME/.local/bin}"

RECREATE=false

# Parse arguments
for arg in "$@"; do
  case "$arg" in
    --recreate) RECREATE=true ;;
    -h|--help)
      sed -n '2,10p' "$0" | sed 's/^# \{0,1\}//'
      exit 0
      ;;
    *)
      echo "Unknown argument: $arg (try --help)" >&2
      exit 1
      ;;
  esac
done

# Color output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m'

log_info() { echo -e "${GREEN}[INFO]${NC} $1"; }
log_warn() { echo -e "${YELLOW}[WARN]${NC} $1"; }
log_error() { echo -e "${RED}[ERROR]${NC} $1" >&2; }

# Check if a command exists
need_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    log_error "'$1' is required but not installed."
    if [[ "$1" == "docker" ]]; then
      echo "  Install: https://docs.docker.com/get-docker/" >&2
    elif [[ "$1" == "kubectl" ]]; then
      echo "  Install: https://kubernetes.io/docs/tasks/tools/" >&2
    fi
    exit 1
  fi
}

# Install kind if not present
install_kind() {
  local os arch url
  os="$(uname -s | tr '[:upper:]' '[:lower:]')"
  arch="$(uname -m)"
  
  case "$arch" in
    x86_64) arch="amd64" ;;
    aarch64|arm64) arch="arm64" ;;
    *)
      log_error "Unsupported architecture: $arch"
      exit 1
      ;;
  esac

  mkdir -p "$INSTALL_DIR"
  url="https://kind.sigs.k8s.io/dl/${KIND_VERSION}/kind-${os}-${arch}"
  
  log_info "Installing kind ${KIND_VERSION} to ${INSTALL_DIR}/kind ..."
  if ! curl -fsSL "$url" -o "${INSTALL_DIR}/kind"; then
    log_error "Failed to download kind from $url"
    exit 1
  fi
  chmod +x "${INSTALL_DIR}/kind"
  
  # Add to PATH if not already there
  if [[ ":$PATH:" != *":${INSTALL_DIR}:"* ]]; then
    export PATH="${INSTALL_DIR}:$PATH"
    log_info "Added ${INSTALL_DIR} to PATH (this session only)"
    log_warn "To make permanent, add to ~/.bashrc: export PATH=\"${INSTALL_DIR}:\$PATH\""
  fi
}

# Ensure kind is available
ensure_kind() {
  if command -v kind >/dev/null 2>&1; then
    return
  fi
  install_kind
  need_cmd kind
}

# Ensure Docker is running
ensure_docker() {
  need_cmd docker
  if ! docker info >/dev/null 2>&1; then
    log_error "Docker is installed but not reachable. Start Docker and retry."
    exit 1
  fi
}

# Configure kubeconfig
configure_kubeconfig() {
  mkdir -p "$HOME/.kube"
  kind export kubeconfig --name "$CLUSTER_NAME"
  kubectl config use-context "kind-${CLUSTER_NAME}"
}

main() {
  need_cmd kubectl
  ensure_docker
  ensure_kind

  # Check if cluster already exists
  if kind get clusters 2>/dev/null | grep -qx "$CLUSTER_NAME"; then
    if [[ "$RECREATE" == true ]]; then
      log_info "Deleting existing cluster '${CLUSTER_NAME}' ..."
      kind delete cluster --name "$CLUSTER_NAME"
    else
      log_info "Cluster '${CLUSTER_NAME}' already exists."
      configure_kubeconfig
      kubectl cluster-info
      echo ""
      log_info "Cluster ready."
      echo ""
      echo "Next steps:"
      echo "  1. source ./scripts/exam-setup.sh  (load aliases)"
      echo "  2. k create ns exercise-01          (start first exercise)"
      exit 0
    fi
  fi

  # Create cluster with specific Kubernetes version
  echo ""
  log_info "Creating kind cluster '${CLUSTER_NAME}' with Kubernetes ${KUBE_VERSION} ..."
  log_info "(This may take 1-2 minutes on first run)"
  echo ""
  
  kind create cluster \
    --name "$CLUSTER_NAME" \
    --image "kindest/node:${KUBE_VERSION}" \
    --wait 300s

  configure_kubeconfig

  echo ""
  log_info "Cluster ready!"
  kubectl cluster-info
  kubectl get nodes -o wide
  
  echo ""
  echo "📌 Context: kind-${CLUSTER_NAME}"
  echo "📌 Next steps:"
  echo "   1. source ./scripts/exam-setup.sh  (load aliases + completion)"
  echo "   2. k get nodes                      (verify setup)"
  echo "   3. k create ns exercise-01          (start first exercise)"
  echo ""
  log_warn "To delete this cluster later: kind delete cluster --name ${CLUSTER_NAME}"
}

main "$@"
