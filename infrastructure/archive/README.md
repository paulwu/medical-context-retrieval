# Medical RAG System - Azure Deployment Guide

This guide explains how to deploy the Medical RAG system to Azure for global access.

## Architecture Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Azure Container Apps                    │
│  ┌─────────────────────────────────────────────────────┐   │
│  │  Medical RAG App (Voilà)                            │   │
│  │  - Auto-scaling (1-10 replicas)                     │   │
│  │  - HTTPS ingress                                     │   │
│  │  - Health checks                                     │   │
│  └────────────┬────────────────────────────────────────┘   │
└───────────────┼──────────────────────────────────────────────┘
                │
                │ Managed Identity
                ▼
    ┌───────────────────────┐
    │   Azure Key Vault     │
    │  - API Keys           │
    │  - Endpoints          │
    │  - Model Names        │
    └───────────────────────┘
                │
                │
                ▼
    ┌───────────────────────┐
    │  Azure OpenAI         │
    │  - Embeddings         │
    │  - Chat Completions   │
    └───────────────────────┘
```

## Prerequisites

1. **Azure CLI** - [Install](https://docs.microsoft.com/en-us/cli/azure/install-azure-cli)
2. **Docker** - [Install](https://docs.docker.com/get-docker/)
3. **Azure Subscription** with:
   - Contributor or Owner role
   - Azure OpenAI Service deployed

## Quick Start

### 1. Set Environment Variables (Optional)

```bash
export RESOURCE_GROUP="medical-rag-rg"
export LOCATION="eastus"
export ENVIRONMENT="prod"
export AZURE_OPENAI_ENDPOINT="https://your-openai.openai.azure.com"
export AZURE_OPENAI_API_KEY="your-api-key"
export AOAI_EMBED_MODEL="text-embedding-ada-002"
export AOAI_CHAT_MODEL="gpt-5-mini"
```

### 2. Run Deployment Script

```bash
chmod +x deploy.sh
./deploy.sh
```

The script will:
- ✅ Create Azure Resource Group
- ✅ Deploy infrastructure (Key Vault, Container Registry, Container Apps)
- ✅ Build Docker image
- ✅ Push image to Azure Container Registry
- ✅ Deploy container to Azure Container Apps
- ✅ Configure secrets from Key Vault

### 3. Access Your Application

After deployment completes, you'll see output like:

```
🎉 Deployment Complete!
==================================

📱 Application URL: https://medical-rag-app-prod.eastus.azurecontainerapps.io
🔐 Key Vault: medical-rag-kv-xyz123
📦 Container Registry: medicalragacrxyz123.azurecr.io
🏷️  Image Tag: 20250102-143022
```

Visit the Application URL to access your deployed system!

## Manual Deployment Steps

If you prefer manual deployment or need to customize:

### 1. Create Resource Group

```bash
az group create \
    --name medical-rag-rg \
    --location eastus
```

### 2. Deploy Infrastructure

```bash
az deployment group create \
    --resource-group medical-rag-rg \
    --template-file infrastructure/main.bicep \
    --parameters \
        environmentName=prod \
        azureOpenAIEndpoint="https://your-openai.openai.azure.com" \
        azureOpenAIApiKey="your-api-key" \
        embeddingModel="text-embedding-ada-002" \
        chatModel="gpt-5-mini"
```

### 3. Build and Push Docker Image

```bash
# Get ACR name from deployment output
ACR_NAME=$(az deployment group show \
    --resource-group medical-rag-rg \
    --name main \
    --query properties.outputs.containerRegistryLoginServer.value -o tsv)

# Login to ACR
az acr login --name ${ACR_NAME%%.*}

# Build and push
docker build -t ${ACR_NAME}/medical-rag:latest .
docker push ${ACR_NAME}/medical-rag:latest
```

### 4. Update Container App

```bash
az containerapp update \
    --name medical-rag-app-prod \
    --resource-group medical-rag-rg \
    --image ${ACR_NAME}/medical-rag:latest
```

## Configuration

### Environment Variables

The following environment variables are automatically configured from Key Vault:

- `AZURE_OPENAI_ENDPOINT` - Azure OpenAI service endpoint
- `AZURE_OPENAI_API_KEY` - API key for authentication
- `AOAI_EMBED_MODEL` - Embedding model name
- `AOAI_CHAT_MODEL` - Chat completion model name

### Scaling Configuration

Auto-scaling is configured in `main.bicep`:

```bicep
scale: {
  minReplicas: 1          // Always-on for fast response
  maxReplicas: 10         // Scale up to 10 instances
  rules: [
    {
      name: 'http-scaling'
      http: {
        metadata: {
          concurrentRequests: '50'  // Scale at 50 concurrent requests
        }
      }
    }
  ]
}
```

### Resource Sizing

Current configuration (adjustable in `main.bicep`):

- **CPU**: 1.0 cores
- **Memory**: 2GB
- **Port**: 8866

## Monitoring and Troubleshooting

### View Logs

```bash
# Stream live logs
az containerapp logs show \
    --name medical-rag-app-prod \
    --resource-group medical-rag-rg \
    --follow

# View recent logs
az containerapp logs show \
    --name medical-rag-app-prod \
    --resource-group medical-rag-rg \
    --tail 100
```

### Check Application Health

```bash
# Get application status
az containerapp show \
    --name medical-rag-app-prod \
    --resource-group medical-rag-rg \
    --query properties.runningStatus
```

### View Metrics in Azure Portal

1. Navigate to Container App resource
2. Go to "Metrics" blade
3. View:
   - HTTP request rate
   - Response times
   - Replica count
   - CPU/Memory usage

## Global Distribution

For worldwide kiosk access, add Azure Front Door:

```bash
# Create Front Door profile
az afd profile create \
    --profile-name medical-rag-cdn \
    --resource-group medical-rag-rg \
    --sku Premium_AzureFrontDoor

# Add Container App as origin
az afd origin create \
    --resource-group medical-rag-rg \
    --profile-name medical-rag-cdn \
    --origin-group-name default-origin-group \
    --origin-name container-app-origin \
    --host-name <your-container-app-fqdn> \
    --origin-host-header <your-container-app-fqdn> \
    --priority 1 \
    --weight 1000
```

## Security Best Practices

✅ **Implemented**:
- Secrets stored in Azure Key Vault (not in code)
- Managed Identity for authentication (no passwords)
- HTTPS-only ingress
- Soft delete enabled on Key Vault
- RBAC authorization on Key Vault

🔒 **Additional Recommendations**:
1. Enable Azure Front Door WAF for DDoS protection
2. Configure custom domain with SSL certificate
3. Set up Azure Monitor alerts for failures
4. Enable diagnostic logging
5. Implement Azure Private Link for internal-only access (if needed)

## Cost Optimization

Current setup costs (approximate):
- Container Apps: $0.000024/vCPU-second + $0.000003/GiB-second
- Container Registry: $5/month (Basic tier)
- Key Vault: $0.03/10k operations
- Log Analytics: Pay-as-you-go

**Estimated monthly cost for low-medium traffic**: $50-150/month

**Cost reduction tips**:
- Scale minReplicas to 0 during off-hours (add warmup time)
- Use consumption-based Log Analytics
- Clean up old container images in ACR

## Updating the Application

To deploy new changes:

```bash
# Option 1: Run deployment script again
./deploy.sh

# Option 2: Manual update
docker build -t ${ACR_NAME}/medical-rag:$(date +%Y%m%d-%H%M%S) .
docker push ${ACR_NAME}/medical-rag:latest
az containerapp update \
    --name medical-rag-app-prod \
    --resource-group medical-rag-rg \
    --image ${ACR_NAME}/medical-rag:latest
```

## Cleanup

To delete all resources:

```bash
az group delete \
    --name medical-rag-rg \
    --yes \
    --no-wait
```

## Support

For issues or questions:
1. Check application logs
2. Review Azure Portal metrics
3. Verify Key Vault secrets are accessible
4. Ensure Azure OpenAI service is running

## Next Steps

After deployment:
1. ✅ Test the application URL
2. ✅ Configure custom domain (optional)
3. ✅ Set up monitoring alerts
4. ✅ Configure Azure Front Door for global CDN (optional)
5. ✅ Set up CI/CD pipeline (GitHub Actions or Azure DevOps)
