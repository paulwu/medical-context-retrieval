#!/bin/bash
set -euo pipefail

echo "deploy.sh is deprecated. Infrastructure is managed via Terraform in the infrastructure/ directory."
echo "Use package.sh (or your packaging workflow) to build and push container images."
exit 0

: <<'LEGACY_DEPLOY_SCRIPT'
#!/bin/bash
set -e

# Medical RAG System - Deployment Script
# Deploys the application to Azure Container Apps with Key Vault integration

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Configuration
RESOURCE_GROUP="${RESOURCE_GROUP:-medical-rag-rg}"
LOCATION="${LOCATION:-eastus}"
ENVIRONMENT="${ENVIRONMENT:-prod}"
APP_NAME="medical-rag"

echo -e "${GREEN}🚀 Medical RAG Deployment Script${NC}"
echo "=================================="
echo ""

# Check if Azure CLI is installed
if ! command -v az &> /dev/null; then
    echo -e "${RED}❌ Azure CLI is not installed. Please install it first.${NC}"
    exit 1
fi

# Check if logged in
echo -e "${YELLOW}📋 Checking Azure CLI authentication...${NC}"
if ! az account show &> /dev/null; then
    echo -e "${YELLOW}🔑 Please login to Azure...${NC}"
    az login
fi

# Show current subscription
SUBSCRIPTION=$(az account show --query name -o tsv)
echo -e "${GREEN}✅ Using subscription: ${SUBSCRIPTION}${NC}"
echo ""

# Prompt for secrets if not set
if [ -z "$AZURE_OPENAI_ENDPOINT" ]; then
    read -p "Enter Azure OpenAI Endpoint: " AZURE_OPENAI_ENDPOINT
fi

if [ -z "$AZURE_OPENAI_API_KEY" ]; then
    read -sp "Enter Azure OpenAI API Key: " AZURE_OPENAI_API_KEY
    echo ""
fi

if [ -z "$AOAI_EMBED_MODEL" ]; then
    read -p "Enter Embedding Model Name (default: text-embedding-ada-002): " AOAI_EMBED_MODEL
    AOAI_EMBED_MODEL=${AOAI_EMBED_MODEL:-text-embedding-ada-002}
fi

if [ -z "$AOAI_CHAT_MODEL" ]; then
    read -p "Enter Chat Model Name (default: gpt-5-mini): " AOAI_CHAT_MODEL
    AOAI_CHAT_MODEL=${AOAI_CHAT_MODEL:-gpt-5-mini}
fi

# Create resource group
echo -e "${YELLOW}📦 Creating resource group: ${RESOURCE_GROUP}...${NC}"
az group create \
    --name $RESOURCE_GROUP \
    --location $LOCATION \
    --output none

echo -e "${GREEN}✅ Resource group created${NC}"
echo ""

# Deploy infrastructure using Bicep
echo -e "${YELLOW}🏗️  Deploying infrastructure with Bicep...${NC}"
DEPLOYMENT_OUTPUT=$(az deployment group create \
    --resource-group $RESOURCE_GROUP \
    --template-file infrastructure/main.bicep \
    --parameters \
        environmentName=$ENVIRONMENT \
        appName=$APP_NAME \
        azureOpenAIEndpoint=$AZURE_OPENAI_ENDPOINT \
        azureOpenAIApiKey=$AZURE_OPENAI_API_KEY \
        embeddingModel=$AOAI_EMBED_MODEL \
        chatModel=$AOAI_CHAT_MODEL \
    --output json)

# Extract outputs
CONTAINER_REGISTRY=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.containerRegistryLoginServer.value')
CONTAINER_APP_URL=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.containerAppUrl.value')
KEY_VAULT_NAME=$(echo $DEPLOYMENT_OUTPUT | jq -r '.properties.outputs.keyVaultName.value')

echo -e "${GREEN}✅ Infrastructure deployed${NC}"
echo -e "  Registry: ${CONTAINER_REGISTRY}"
echo -e "  Key Vault: ${KEY_VAULT_NAME}"
echo ""

# Build and push Docker image
echo -e "${YELLOW}🐳 Building Docker image...${NC}"
IMAGE_TAG=$(date +%Y%m%d-%H%M%S)
IMAGE_NAME="${CONTAINER_REGISTRY}/${APP_NAME}:${IMAGE_TAG}"
LATEST_IMAGE="${CONTAINER_REGISTRY}/${APP_NAME}:latest"

# Login to ACR
echo -e "${YELLOW}🔑 Logging in to Azure Container Registry...${NC}"
az acr login --name ${CONTAINER_REGISTRY%%.*}

# Build image
docker build -t $IMAGE_NAME -t $LATEST_IMAGE .

# Push image
echo -e "${YELLOW}📤 Pushing Docker image to ACR...${NC}"
docker push $IMAGE_NAME
docker push $LATEST_IMAGE

echo -e "${GREEN}✅ Docker image pushed${NC}"
echo ""

# Update Container App with new image
echo -e "${YELLOW}🔄 Updating Container App with new image...${NC}"
CONTAINER_APP_NAME="${APP_NAME}-app-${ENVIRONMENT}"

az containerapp update \
    --name $CONTAINER_APP_NAME \
    --resource-group $RESOURCE_GROUP \
    --image $LATEST_IMAGE \
    --output none

echo -e "${GREEN}✅ Container App updated${NC}"
echo ""

# Display deployment information
echo -e "${GREEN}🎉 Deployment Complete!${NC}"
echo "=================================="
echo ""
echo -e "${GREEN}📱 Application URL:${NC} ${CONTAINER_APP_URL}"
echo -e "${GREEN}🔐 Key Vault:${NC} ${KEY_VAULT_NAME}"
echo -e "${GREEN}📦 Container Registry:${NC} ${CONTAINER_REGISTRY}"
echo -e "${GREEN}🏷️  Image Tag:${NC} ${IMAGE_TAG}"
echo ""
echo -e "${YELLOW}💡 Next Steps:${NC}"
echo "  1. Visit ${CONTAINER_APP_URL} to access your application"
echo "  2. Configure custom domain in Azure Portal (if needed)"
echo "  3. Set up Azure Front Door for global distribution (if needed)"
echo "  4. Monitor logs: az containerapp logs show -n ${CONTAINER_APP_NAME} -g ${RESOURCE_GROUP}"
echo ""
LEGACY_DEPLOY_SCRIPT
