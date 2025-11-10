#!/bin/bash
set -euo pipefail

# Builds the application container image and pushes it to the Azure Container Registry
# provisioned by Terraform. Requires Terraform state to be initialized/applied first.

TF_DIR="infrastructure"
IMAGE_NAME="medical-context-rag"
IMAGE_TAG=""
BUILD_CONTEXT="."

usage() {
  cat <<'EOF'
Usage: ./package.sh [--image <name>] [--tag <tag>] [--context <path>]

Options:
  --image    Container image repository name (default: medical-context-rag)
  --tag      Image tag (default: timestamp YYYYMMDD-HHMMSS)
  --context  Build context directory (default: current directory)
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
    --context)
      BUILD_CONTEXT="$2"
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

if [[ -z "$IMAGE_TAG" ]]; then
  IMAGE_TAG="$(date +%Y%m%d-%H%M%S)"
fi

if [[ ! -d "$TF_DIR" ]]; then
  echo "ERROR: Terraform directory '$TF_DIR' not found." >&2
  exit 1
fi

ACR_LOGIN_SERVER=$(terraform -chdir="$TF_DIR" output -raw container_registry_login_server 2>/dev/null || true)
if [[ -z "$ACR_LOGIN_SERVER" ]]; then
  echo "ERROR: Terraform output 'container_registry_login_server' is empty." >&2
  echo "       Ensure 'terraform apply' has been run in $TF_DIR and the registry exists." >&2
  exit 1
fi

REGISTRY_NAME="${ACR_LOGIN_SERVER%%.*}"

if ! az account show >/dev/null 2>&1; then
  echo "ERROR: Azure CLI is not logged in. Run 'az login' and retry." >&2
  exit 1
fi

echo "Building container image with Azure Container Registry Tasks..."
az acr build \
  --registry "$REGISTRY_NAME" \
  --image "$IMAGE_NAME:$IMAGE_TAG" \
  --image "$IMAGE_NAME:latest" \
  "$BUILD_CONTEXT"

FULL_IMAGE="$ACR_LOGIN_SERVER/$IMAGE_NAME:$IMAGE_TAG"
LATEST_IMAGE="$ACR_LOGIN_SERVER/$IMAGE_NAME:latest"

echo "Image build complete."

echo "Summary:"
echo "  Registry : $ACR_LOGIN_SERVER"
echo "  Image    : $IMAGE_NAME"
echo "  Tags     : $IMAGE_TAG, latest"

CONTAINER_APP_NAME=$(terraform -chdir="$TF_DIR" output -raw container_app_name 2>/dev/null || true)
if [[ -n "$CONTAINER_APP_NAME" ]]; then
  RG_NAME=$(terraform -chdir="$TF_DIR" output -raw medical_ctx_rag_resource_group_name 2>/dev/null || true)
  if [[ -n "$RG_NAME" ]]; then
    printf '\nTo roll out the new revision:\n'
    echo "  terraform -chdir=$TF_DIR plan output=tfplan "
    echo "  terraform -chdir=$TF_DIR apply"
    echo "    or"
    echo "  az containerapp update --name $CONTAINER_APP_NAME --resource-group $RG_NAME --image $LATEST_IMAGE"
  fi
fi
