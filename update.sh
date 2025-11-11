#!/bin/bash
set -euo pipefail

TF_DIR="infrastructure"
IMAGE_NAME="medical-context-rag"
IMAGE_TAG="latest"

usage() {
  cat <<'EOF'
Usage: ./update.sh [--image <name>] [--tag <tag>]

Assumes the image exists in the Azure Container Registry referenced by Terraform outputs
and that terraform apply has been executed at least once.

Options:
  --image    Container image repository name (default: medical-context-rag)
  --tag      Container image tag to deploy (default: latest)
  --help     Show this message
EOF
}

require_cmd() {
  if ! command -v "$1" >/dev/null 2>&1; then
    echo "ERROR: Required command '$1' not found on PATH." >&2
    exit 1
  fi
}

while [[ $# -gt 0 ]]; do
  case "$1" in
    --image)
      IMAGE_NAME="$2"
      shift 2
      ;;
    --tag)
      IMAGE_TAG="$2"
      shift 2
      ;;
    --help|-h)
      usage
      exit 0
      ;;
    *)
      echo "ERROR: Unknown option '$1'." >&2
      usage
      exit 1
      ;;
  esac
done

require_cmd terraform
require_cmd az

if [[ ! -d "$TF_DIR" ]]; then
  echo "ERROR: Terraform directory '$TF_DIR' not found." >&2
  exit 1
fi

CONTAINER_APP_NAME=$(terraform -chdir="$TF_DIR" output -raw container_app_name 2>/dev/null || true)
if [[ -z "$CONTAINER_APP_NAME" ]]; then
  echo "ERROR: Terraform output 'container_app_name' is empty. Run 'terraform apply' in $TF_DIR first." >&2
  exit 1
fi

RESOURCE_GROUP=$(terraform -chdir="$TF_DIR" output -raw medical_ctx_rag_resource_group_name 2>/dev/null || true)
if [[ -z "$RESOURCE_GROUP" ]]; then
  echo "ERROR: Terraform output 'medical_ctx_rag_resource_group_name' is empty." >&2
  exit 1
fi

ACR_LOGIN_SERVER=$(terraform -chdir="$TF_DIR" output -raw container_registry_login_server 2>/dev/null || true)
if [[ -z "$ACR_LOGIN_SERVER" ]]; then
  echo "ERROR: Terraform output 'container_registry_login_server' is empty." >&2
  exit 1
fi

if ! az account show >/dev/null 2>&1; then
  echo "ERROR: Azure CLI is not logged in. Run 'az login' and retry." >&2
  exit 1
fi

FULL_IMAGE="$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG"

echo "Updating Container App '$CONTAINER_APP_NAME' in resource group '$RESOURCE_GROUP' to image '$FULL_IMAGE'..."
az containerapp update \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --image "$FULL_IMAGE"

echo "Update complete."
