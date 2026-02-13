# Publish Container App

This guide covers the process of deploying the Medical Context Retrieval application to Azure Container Apps after building the container image with `package.sh`. It includes Azure portal configuration steps, managed identity validation, RBAC assignments for AI Foundry, and troubleshooting guidance for common issues.

## Overview

The deployment workflow consists of:
1. **Build and push the container image** using `package.sh`
2. **Update the Container App** using `update.sh` or Azure portal
3. **Validate managed identity and RBAC** for Azure AI Foundry access
4. **Troubleshoot startup issues** using Log Stream and diagnostic tools

---

## Prerequisites

Before proceeding, ensure you have:

- [ ] Azure CLI installed and logged in (`az login`)
- [ ] Terraform infrastructure deployed (`terraform apply` in `/infrastructure`)
- [ ] Container Registry provisioned with admin access enabled
- [ ] Container App Environment deployed and healthy
- [ ] Access to the Azure Portal with Contributor permissions on the resource group

---

## Step 1: Build and Push Container Image

### Using the `package.sh` Script

The `package.sh` script builds the container image using Azure Container Registry Tasks (no local Docker required):

```bash
cd /workspaces/medical-context-retrieval
./package.sh
```

**What it does:**
1. Reads the ACR login server from Terraform outputs
2. Builds the container image using `az acr build`
3. Tags the image with both a timestamp tag and `latest`
4. Outputs the full image path and update commands

**Sample output:**
```
Building container image with Azure Container Registry Tasks...
Image build complete.
Summary:
  Registry : medctxdemoacr.azurecr.io
  Image    : medical-context-rag
  Tags     : 20260213-143022, latest

To roll out the new revision:
  az containerapp update --name medctx-demo-ca --resource-group EXP-HLS-MedicalContext-RG --image medctxdemoacr.azurecr.io/medical-context-rag:latest
```

### Custom Options

| Option | Description | Default |
|--------|-------------|---------|
| `--image <name>` | Container image repository name | `medical-context-rag` |
| `--tag <tag>` | Image tag | Timestamp `YYYYMMDD-HHMMSS` |
| `--context <path>` | Build context directory | Current directory |

---

## Step 2: Update the Container App

### Option A: Using `update.sh` Script (Recommended)

```bash
./update.sh
```

This script:
1. Retrieves Terraform outputs for Container App name, resource group, and ACR
2. Configures registry credentials on the Container App
3. Updates the Container App to use the new image

### Option B: Using Azure CLI Directly

```bash
# Get values from Terraform
CONTAINER_APP_NAME=$(terraform -chdir=infrastructure output -raw container_app_name)
RESOURCE_GROUP=$(terraform -chdir=infrastructure output -raw medical_ctx_rag_resource_group_name)
ACR_LOGIN_SERVER=$(terraform -chdir=infrastructure output -raw container_registry_login_server)

# Update the container app
az containerapp update \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --image "$ACR_LOGIN_SERVER/medical-context-rag:latest"
```

### Option C: Using Azure Portal

1. Navigate to **Azure Portal** > **Container Apps** > **[Your Container App Name]**
2. Go to **Application** > **Containers** in the left menu
3. Click **Edit and deploy**
4. Under **Container image**, update the image path:
   ```
   <your-acr>.azurecr.io/medical-context-rag:latest
   ```
5. Click **Create** to deploy a new revision

---

## Step 3: Configure Environment Variables (Azure Portal)

The application requires several environment variables to connect to Azure AI Foundry and other services.

### Navigate to Environment Variables

1. Go to **Container Apps** > **[Your App]** > **Application** > **Containers**
2. Click **Edit and deploy**
3. Select the container and scroll to **Environment variables**

### Required Environment Variables

| Variable | Description | Example |
|----------|-------------|---------|
| `AZURE_OPENAI_ENDPOINT` | AI Foundry/OpenAI endpoint URL | `https://sharedaifoundry.openai.azure.com` |
| `AZURE_OPENAI_API_KEY` | API key (if key auth enabled) | `(Secret reference or value)` |
| `AOAI_EMBED_MODEL` | Embedding model deployment name | `text-embedding-3-large` |
| `AOAI_CHAT_MODEL` | Chat completion model deployment name | `gpt-5-mini` |

### Using Key Vault Secrets (Recommended)

Instead of storing API keys directly, reference Key Vault secrets:

1. In the **Secrets** section of Container App settings, add a new secret:
   - **Name:** `azure-openai-api-key`
   - **Type:** Key Vault reference
   - **Key Vault secret URI:** `https://<keyvault-name>.vault.azure.net/secrets/azure-openai-api-key`
2. In environment variables, reference the secret:
   - **Name:** `AZURE_OPENAI_API_KEY`
   - **Source:** Secret reference
   - **Value:** `azure-openai-api-key`

---

## Step 4: Validate Managed Identity

The Container App uses a **system-assigned managed identity** for authenticating to Azure services without API keys.

### Check That Managed Identity Is Enabled

1. Go to **Container Apps** > **[Your App]** > **Settings** > **Identity**
2. Verify the **System assigned** tab shows **Status: On**
3. Copy the **Object (principal) ID**—you need this for RBAC assignments

### Verify via Azure CLI

```bash
CONTAINER_APP_NAME=$(terraform -chdir=infrastructure output -raw container_app_name)
RESOURCE_GROUP=$(terraform -chdir=infrastructure output -raw medical_ctx_rag_resource_group_name)

az containerapp show \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --query "identity.principalId" -o tsv
```

---

## Step 5: Configure RBAC for AI Foundry (Entra ID Access)

When **local authentication is disabled** on the AI Foundry account (enforced by Azure Policy), the Container App must use its managed identity with proper RBAC roles.

### Required Role: Cognitive Services User

1. Navigate to **Azure Portal** > **Cognitive Services** / **Azure AI Services** > **[Your AI Foundry Resource]**
2. Go to **Access control (IAM)** in the left menu
3. Click **+ Add** > **Add role assignment**
4. Select role: **Cognitive Services User**
5. Click **Next**, then **Select members**
6. Search for your Container App name or paste the **Principal ID**
7. Click **Select**, then **Review + assign**

### Assign via Azure CLI

```bash
# Get the Container App's managed identity principal ID
PRINCIPAL_ID=$(terraform -chdir=infrastructure output -raw container_app_identity_principal_id)

# Get the AI Foundry account resource ID
AI_FOUNDRY_ID="/subscriptions/<subscription-id>/resourceGroups/<rg-name>/providers/Microsoft.CognitiveServices/accounts/<ai-foundry-name>"

# Assign Cognitive Services User role
az role assignment create \
  --role "Cognitive Services User" \
  --assignee-object-id "$PRINCIPAL_ID" \
  --assignee-principal-type ServicePrincipal \
  --scope "$AI_FOUNDRY_ID"
```

### Verify Role Assignment

```bash
az role assignment list \
  --scope "$AI_FOUNDRY_ID" \
  --query "[?principalId=='$PRINCIPAL_ID'].{Role:roleDefinitionName,Principal:principalId}" \
  -o table
```

Expected output:
```
Role                      Principal
------------------------  ------------------------------------
Cognitive Services User   d0f20ee3-2c9a-42d7-8b94-bb5394b26f81
```

---

## Step 6: Update Application for Managed Identity (No API Key)

When API key access is disabled, the application must use `DefaultAzureCredential` or `ManagedIdentityCredential` from the Azure Identity SDK.

### Code Changes

In [rag/embeddings.py](../rag/embeddings.py) and related modules, update the OpenAI client initialization:

```python
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from openai import AzureOpenAI

# For Managed Identity authentication (no API key)
token_provider = get_bearer_token_provider(
    DefaultAzureCredential(),
    "https://cognitiveservices.azure.com/.default"
)

client = AzureOpenAI(
    azure_endpoint=os.getenv("AZURE_OPENAI_ENDPOINT"),
    azure_ad_token_provider=token_provider,
    api_version="2024-08-01-preview"
)
```

### Environment Variable Update

When using managed identity, omit `AZURE_OPENAI_API_KEY` entirely. The SDK automatically uses the Container App's system-assigned identity.

---

## Troubleshooting

### Using Log Stream

The **Log Stream** provides real-time container logs for debugging startup issues.

#### Access Log Stream (Azure Portal)

1. Go to **Container Apps** > **[Your App]** > **Monitoring** > **Log stream**
2. Select the **Container** and **Replica** to view
3. Logs appear in real-time as the container runs

#### Access Logs via Azure CLI

```bash
az containerapp logs show \
  --name "$CONTAINER_APP_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --type console \
  --follow
```

### Common Issues and Solutions

#### Issue: "disableLocalAuth is set to be true"

**Symptom:** Application fails with error:
```
Failed to list key. disableLocalAuth is set to be true
```

**Cause:** The AI Foundry account has key-based authentication disabled (by Azure Policy), but the app is trying to use an API key.

**Solution:**
1. Remove `AZURE_OPENAI_API_KEY` from environment variables
2. Assign `Cognitive Services User` role to the Container App's managed identity (see Step 5)
3. Update application code to use `DefaultAzureCredential` (see Step 6)

---

#### Issue: "403 Forbidden" when calling AI Foundry

**Symptom:** API calls return HTTP 403 with message:
```
Access denied due to missing or invalid credentials
```

**Cause:** The managed identity doesn't have the required RBAC role.

**Solution:**
1. Verify the managed identity principal ID is correct
2. Assign `Cognitive Services User` role at the AI Foundry resource scope
3. Wait 5-10 minutes for RBAC propagation
4. Restart the Container App revision

---

#### Issue: Container fails to pull image

**Symptom:** Container App shows status "Waiting" or "ImagePullBackOff"

**Cause:** ACR authentication is not configured or credentials are invalid.

**Solution:**
1. **Verify ACR admin is enabled:**
   ```bash
   az acr show --name <acr-name> --query "adminUserEnabled"
   ```
2. **Re-configure registry credentials:**
   ```bash
   ./update.sh
   ```
3. **Or assign AcrPull role to managed identity:**
   ```bash
   az role assignment create \
     --role "AcrPull" \
     --assignee-object-id "$PRINCIPAL_ID" \
     --assignee-principal-type ServicePrincipal \
     --scope "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.ContainerRegistry/registries/<acr-name>"
   ```

---

#### Issue: Application crashes on startup

**Symptom:** Log stream shows Python exceptions or `exit code 1`

**Solution:**
1. Check Log Stream for the specific error message
2. Verify all required environment variables are set
3. Ensure `.env` file variables are configured as Container App secrets
4. Test locally first:
   ```bash
   docker run -p 8866:8866 --env-file .env <acr>.azurecr.io/medical-context-rag:latest
   ```

---

#### Issue: Health check failures

**Symptom:** Container keeps restarting, health probe failures in logs

**Cause:** The application takes longer than the health check start period to initialize.

**Solution:**
1. Go to **Container Apps** > **[Your App]** > **Application** > **Containers**
2. Click **Edit and deploy**
3. Under **Health probes**, adjust:
   - **Initial delay:** Increase to 60-90 seconds
   - **Timeout:** Increase to 15 seconds
   - **Period:** Set to 30 seconds

---

## Validating the Deployment

### Quick Validation Steps

1. **Check Container App status:**
   ```bash
   az containerapp show \
     --name "$CONTAINER_APP_NAME" \
     --resource-group "$RESOURCE_GROUP" \
     --query "properties.runningStatus"
   ```

2. **Get the application URL:**
   ```bash
   az containerapp show \
     --name "$CONTAINER_APP_NAME" \
     --resource-group "$RESOURCE_GROUP" \
     --query "properties.configuration.ingress.fqdn" -o tsv
   ```

3. **Test the endpoint:**
   ```bash
   curl -I "https://$(az containerapp show --name $CONTAINER_APP_NAME --resource-group $RESOURCE_GROUP --query 'properties.configuration.ingress.fqdn' -o tsv)"
   ```

4. **Open in browser:**
   Navigate to the URL shown in Terraform output or Azure portal.

---

## References

- [Azure Container Apps documentation](https://learn.microsoft.com/en-us/azure/container-apps/)
- [Container Apps managed identity](https://learn.microsoft.com/en-us/azure/container-apps/managed-identity)
- [Azure AI Services RBAC roles](https://learn.microsoft.com/en-us/azure/ai-services/authentication)
- [Disable local authentication on Cognitive Services](https://learn.microsoft.com/en-us/azure/ai-services/disable-local-auth)
- [package.sh](../package.sh) - Container build script
- [update.sh](../update.sh) - Container update script
- [Infrastructure Terraform](../infrastructure/) - Terraform configuration
