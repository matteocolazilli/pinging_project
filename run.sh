#!/usr/bin/env bash

set -euo pipefail

IFS=$'\n\t'
ARCH=$(uname -m)

### Utility functions ###
log()    { printf '\033[1;34m[INFO]\033[0m  %s\n' "$*"; }
warn()   { printf '\033[1;33m[WARN]\033[0m  %s\n' "$*"; }
error()  { printf '\033[1;31m[ERROR]\033[0m %s\n' "$*"; exit 1; }

### Dependency check ###
for cmd in docker kind kubectl curl jq; do
  if ! type -P "$cmd" > /dev/null 2>&1; then
    error "Command '$cmd' is not installed or not in PATH."
  fi
done

### Docker permissions ###
if [[ $(id -u) -ne 0 ]] && ! groups | grep -qw docker; then
  error "This script must be run as root ('sudo ./run.sh') or the user must belong to the 'docker' group."
fi

### Loading .env ###
if [[ ! -f .env ]]; then
  error ".env file not found. Create .env with the necessary variables."
fi
set -a
source .env
set +a

### Mandatory variables check ###
if [[ -z "${GITHUB_PAT:-}" ]]; then
  error "The GITHUB_PAT variable is not defined in the .env file. Make sure you have set the GitHub Personal Access Token."
fi
if [[ -z "${REPO_OWNER:-}" ]]; then
  error "The REPO_OWNER variable is not defined in the .env file. Make sure you have set the repository owner."
fi
if [[ -z "${REPO_NAME:-}" ]]; then
  error "The REPO_NAME variable is not defined in the .env file. Make sure you have set the repository name."
fi
if [[ -z "${MACHINE_ID:-}" ]]; then
  error "The MACHINE_ID variable is not defined in the .env file. Make sure you have set the machine identifier."
fi

### Registration token generation ###
log "Requesting registration token from GitHub..."
RUNNER_TOKEN=$(curl -sX POST \
  -H "Authorization: token ${GITHUB_PAT}" \
  -H "Accept: application/vnd.github+json" \
  "https://api.github.com/repos/${REPO_OWNER}/${REPO_NAME}/actions/runners/registration-token" \
  | jq -r .token)


if [[ -z "$RUNNER_TOKEN" ]]; then
  error "Could not get registration token. Check the PAT and 'repo' permissions."
fi

### Previous Kind cluster cleanup ###
if kind get clusters | grep -qw kind; then
  log "Deleting existing Kind cluster..."
  kind delete cluster --name kind
fi

### Kind cluster creation ###
log "Creating Kind cluster..."
kind create cluster --name kind --config kind/kind-config.yaml


### Github Actions Runner Docker image preparation ###
if [ "$ARCH" = "arm64" ] || [ "$ARCH" = "aarch64" ]; then
  log "Building runner image..."
  # Build the image in your local Docker (on Mac)
  docker build -t gh-actions-runner-mac:latest ./macConfig
  log "Loading images into the cluster..."
  # Load it into kind (this works across platforms)
  kind load docker-image gh-actions-runner-mac:latest --name kind
else
  log "Pulling runner image..."
  docker pull ghcr.io/actions/actions-runner:latest
  log "Loading images into the cluster..."
  kind load docker-image ghcr.io/actions/actions-runner:latest --name kind
fi

### Basic configurations ###
log "Applying setup resources (namespace, RBAC)..."
kubectl apply -f k8s/setup/

### Saving the Secret ###
log "Creating the 'github-runner-secret' Secret..."
kubectl create secret generic github-runner-secret \
  -n github-runner \
  --from-literal=runner-token="${RUNNER_TOKEN}" \
  --dry-run=client -o yaml \
| kubectl apply -f -

### Deploying the application and the runner ###
log "Deploying the application in the 'ping-app' namespace..."
kubectl apply -f k8s/app/ -n ping-app

log "Deploying the GitHub Actions Runner..."
sed "s/MACHINE_IDENTIFIER/${MACHINE_ID}/g" k8s/runner/runner-deployment.yaml \
  | kubectl apply -f -

log "Operation completed successfully."
