# Development Lifecycle

This guide covers the end-to-end development lifecycle for the Medical Context Retrieval application — from setting up a local development environment to deploying changes in Azure. It is written for new developers joining the project.

## Contents

- [Overview](#overview)
- [Local Development Setup](#local-development-setup)
  - [Prerequisites](#prerequisites)
  - [Environment Configuration](#environment-configuration)
  - [Verify Setup](#verify-setup)
  - [Run the Application Locally](#run-the-application-locally)
- [Making Code Changes](#making-code-changes)
  - [Project Structure](#project-structure)
  - [Development Workflow](#development-workflow)
  - [Testing Changes](#testing-changes)
- [Rebuilding the RAG Pipeline](#rebuilding-the-rag-pipeline)
  - [When to Rebuild](#when-to-rebuild)
  - [Rebuild Steps](#rebuild-steps)
- [Build and Push Container Image](#build-and-push-container-image)
  - [Using package.sh](#using-the-packagesh-script)
  - [Custom Options](#custom-options)
- [Deploy to Azure Container App](#deploy-to-azure-container-app)
  - [Using update.sh](#option-a-using-updatesh-script-recommended)
  - [Using Azure CLI](#option-b-using-azure-cli-directly)
  - [Using Azure Portal](#option-c-using-azure-portal)
- [Configure Environment Variables](#configure-environment-variables-azure-portal)
  - [Required Environment Variables](#required-environment-variables)
  - [Using Key Vault Secrets](#using-key-vault-secrets-recommended)
- [Validate Managed Identity and RBAC](#validate-managed-identity)
  - [Check Managed Identity](#check-that-managed-identity-is-enabled)
  - [Configure RBAC for AI Foundry](#configure-rbac-for-ai-foundry-entra-id-access)
  - [Update Application for Managed Identity](#update-application-for-managed-identity-no-api-key)
- [Infrastructure Changes](#infrastructure-changes)
  - [When to Modify Infrastructure](#when-to-modify-infrastructure)
  - [Terraform Workflow](#terraform-workflow)
- [Troubleshooting](#troubleshooting)
  - [Using Log Stream](#using-log-stream)
  - [Common Issues and Solutions](#common-issues-and-solutions)
- [Validating the Deployment](#validating-the-deployment)
- [References](#references)

---

## Overview

The development-to-deployment workflow:

1. **Set up locally** — install dependencies, configure `.env`, verify setup
2. **Make code changes** — edit Python modules, test with smoke tests and local Docker
3. **Rebuild the RAG pipeline** (if data or chunking/embedding logic changed)
4. **Build and push the container image** using `package.sh`
5. **Deploy to Azure** using `update.sh`
6. **Validate** — check managed identity, RBAC, and application health

---

## Local Development Setup

### Prerequisites

- **Python 3.11+** installed
- **Azure CLI** installed and logged in (`az login`)
- **Terraform** installed (for infrastructure operations)
- **Git** for version control
- Access to an Azure OpenAI endpoint (for embeddings and LLM calls)

### Environment Configuration

1. **Create your `.env` file** from the template:

   ```bash
   cp .env.example .env
   ```

2. **Fill in the required values** (see `.env.example` for descriptions):

   | Variable | Required For | Example |
   |----------|-------------|---------|
   | `AZURE_OPENAI_ENDPOINT` | Both modes | `https://your-endpoint.openai.azure.com` |
   | `AZURE_OPENAI_API_KEY` | Local mode only (optional in Azure — uses managed identity) | `(your key)` |
   | `AOAI_EMBED_MODEL` | Both modes | `text-embedding-3-large` |
   | `AOAI_CHAT_MODEL` | Both modes | `gpt-5-mini` |
   | `STORAGE_MODE` | Mode selection | `local` or `azure` |

   For **local mode** (`STORAGE_MODE=local`), Azure OpenAI endpoint + API key are needed.
   For **azure mode**, set `AZURE_SEARCH_*` and `COSMOS_*` variables. The `AZURE_OPENAI_API_KEY` is **not needed** when the Container App uses managed identity.

3. **Install Python dependencies:**

   ```bash
   pip install -r requirements.txt
   ```

> ⚠️ **Never commit `.env`** — it contains secrets. Only `.env.example` is tracked in git.

### Verify Setup

Run the verification script to confirm everything is configured:

```bash
./verify_setup.sh
```

This checks: Python version, `.env` file, required directories, Python packages, and cache status.

### Run the Application Locally

```bash
# Interactive demo UI (Voilà)
./launch_demo.sh                    # http://localhost:8866

# Admin notebook (Jupyter)
./launch_admin.sh                   # http://localhost:8867

# Or run directly
voila demo.ipynb --template=lab --port=8866
```

---

## Making Code Changes

### Project Structure

| Path | Purpose |
|------|---------|
| `rag/` | Core RAG pipeline (chunking, embeddings, retrieval, headers) |
| `rag/config.py` | Central config — all env vars flow through here |
| `rag/models.py` | `Document` and `Chunk` dataclasses |
| `demo.ipynb` | User-facing search interface |
| `admin.ipynb` | System management (index building, data ingestion) |
| `data_pilot/` | Source medical documents (JSON + PDFs) |
| `cache/` | Local FAISS index + chunk metadata |
| `infrastructure/` | Terraform IaC for Azure resources |

### Development Workflow

1. **Edit code** — all runtime config goes through `rag/config.py` (never call `os.getenv()` directly in other modules)
2. **Test locally** — run the smoke test and optionally the demo UI
3. **Commit** — include meaningful commit messages

### Testing Changes

**Smoke test (offline, no API keys needed):**

```bash
python artifacts/smoke_test.py
```

This validates module imports, FAISS index building, and retriever search using synthetic embeddings.

**Local Docker test (validates the full container):**

```bash
docker build -t medical-context-rag .
docker run -p 8866:8866 --env-file .env medical-context-rag
# Open http://localhost:8866
```

> The `cache/` directory must be populated before building the Docker image. The container expects pre-built FAISS artifacts at startup.

---

## Rebuilding the RAG Pipeline

### When to Rebuild

- New documents added to `data_pilot/`
- Chunking logic changed (`rag/chunking.py`)
- Contextual header generation changed (`rag/headers.py`)
- Embedding model or dimensions changed
- Switching from local to Azure storage mode

### Rebuild Steps

Use the **admin notebook** (`admin.ipynb`) or run the pipeline programmatically:

1. **Load documents** — parse JSON/PDF files from `data_pilot/`
2. **Chunk documents** — semantic ~300-word chunks at paragraph boundaries
3. **Generate contextual headers** — async LLM calls (the project's key innovation)
4. **Generate embeddings** — Azure OpenAI `text-embedding-3-large` (3072 dimensions)
5. **Build index** — FAISS (local mode) or Azure AI Search (azure mode)

For **local mode**, artifacts are written to `cache/`. For **azure mode**, use the migration scripts:

```bash
python create_azure_search_index.py    # Create the Azure AI Search index schema
python populate_azure_search.py        # Upload chunks and embeddings
python migrate_to_cosmos.py            # Migrate document/chunk data to Cosmos DB
```

---

## Build and Push Container Image

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

## Deploy to Azure Container App

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

## Configure Environment Variables (Azure Portal)

The application requires several environment variables to connect to Azure AI Foundry and other services.

### Navigate to Environment Variables

1. Go to **Container Apps** > **[Your App]** > **Application** > **Containers**
2. Click **Edit and deploy**
3. Select the container and scroll to **Environment variables**

### Required Environment Variables

| Variable | Description | Required? |
|----------|-------------|-----------|
| `AZURE_OPENAI_ENDPOINT` | AI Foundry/OpenAI endpoint URL | ✅ Yes |
| `AOAI_EMBED_MODEL` | Embedding model deployment name | ✅ Yes |
| `AOAI_CHAT_MODEL` | Chat completion model deployment name | ✅ Yes |
| `AZURE_OPENAI_API_KEY` | API key for OpenAI | ❌ Not needed — uses managed identity |
| `COSMOS_KEY` | Cosmos DB primary key | ⚠️ Still used (migration to RBAC pending) |
| `AZURE_SEARCH_KEY` | Azure AI Search admin key | ⚠️ Still used (migration to RBAC pending) |

### Authentication Model

The Container App uses **system-assigned managed identity** for Azure OpenAI. The app code (`rag/embeddings.py`, `rag/headers.py`) automatically detects:
- If `AZURE_OPENAI_API_KEY` is set → uses API key auth
- If not set → uses `ManagedIdentityCredential` with token provider

**RBAC required on the AI Foundry account:**
- `Cognitive Services User` — assigned to the Container App's managed identity principal

> **Note:** Cosmos DB and Azure AI Search still use key-based auth via `COSMOS_KEY` and `AZURE_SEARCH_KEY` environment variables. RBAC role assignments have been added in Terraform, but the application code has not yet been migrated.

---

## Validate Managed Identity

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

## Configure RBAC for AI Foundry (Entra ID Access)

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

## Update Application for Managed Identity (No API Key)

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

## Infrastructure Changes

### When to Modify Infrastructure

You need Terraform when:

- Adding or removing Azure services (e.g., enabling AI Search, adding private endpoints)
- Changing SKUs, scaling, or networking configuration
- Modifying RBAC role assignments
- Updating deployment flags (e.g., `deploy_ai_search`, `deploy_private_network`)

You do **not** need Terraform for:

- Application code changes (use `package.sh` + `update.sh`)
- Environment variable changes (use Azure Portal or CLI)
- Data/index updates (use the RAG pipeline scripts)

### Terraform Workflow

```bash
cd infrastructure

# 1. Validate syntax
terraform validate

# 2. Preview changes (requires Azure connectivity)
terraform plan -var-file=environments/exp.tfvars

# 3. Apply (with confirmation)
terraform apply -var-file=environments/exp.tfvars
```

**Key files:**

| File | Purpose |
|------|---------|
| `infrastructure/main.tf` | Resource definitions |
| `infrastructure/variables.tf` | Input variables |
| `infrastructure/outputs.tf` | Exported values (used by `package.sh` and `update.sh`) |
| `infrastructure/environments/exp.tfvars` | Environment-specific configuration |
| `infrastructure/environments/exp.backend.tfvars` | Remote state backend config |

**Deployment flags** in `exp.tfvars` control which services are deployed:

| Flag | Controls |
|------|----------|
| `deploy_infrastructure` | Core resources (RG, Storage, Key Vault) |
| `deploy_private_network` | VNet, private endpoints, DNS |
| `deploy_ai_foundry_instances` | AI Foundry accounts |
| `deploy_ai_model_deployments` | Model deployments in AI Foundry |
| `deploy_container_app_environment` | Container App Environment + App |
| `deploy_ai_search` | Azure AI Search service |
| `deploy_azure_frontdoor` | Azure Front Door CDN/WAF |

> ⚠️ Always run `terraform plan` before `terraform apply` and review changes carefully. Destructive changes (especially to Cosmos DB) can cause data loss.

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

### Check the Version Watermark

The demo UI displays a version string below the title (e.g., `v20260409-105020-b795a6b`). This is the **image tag + git hash**, set at build time by `package.sh`.

| Version displayed | Meaning |
|---|---|
| `v20260409-105020-b795a6b` | Timestamp `YYYYMMDD-HHMMSS` + git short hash |
| `vdev` | Running locally or from an image built without `package.sh` |
| No version shown | Running an image built before the watermark was added |

The version is baked into the Docker image via `APP_VERSION` build arg. To override manually:
```bash
az containerapp update --name medctx-demo-ca --resource-group EXP-HLS-MedicalContext-RG \
  --set-env-vars APP_VERSION=my-custom-version
```

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

### Project Scripts

- [package.sh](../package.sh) — Build container image and push to ACR
- [update.sh](../update.sh) — Deploy image to Container App
- [verify_setup.sh](../verify_setup.sh) — Validate local development setup
- [launch_demo.sh](../launch_demo.sh) — Start the Voilà demo UI
- [launch_admin.sh](../launch_admin.sh) — Start the admin Jupyter notebook

### Project Documentation

- [README.md](../README.md) — Project overview, features, and usage
- [Quickstart-Local.md](../Quickstart-Local.md) — Quick start for local mode
- [Quickstart-EXP.md](../Quickstart-EXP.md) — Quick start for the EXP environment
- [Infrastructure README](../infrastructure/ReadMe.md) — Terraform configuration overview

### Azure Documentation

- [Azure Container Apps](https://learn.microsoft.com/en-us/azure/container-apps/)
- [Container Apps managed identity](https://learn.microsoft.com/en-us/azure/container-apps/managed-identity)
- [Azure AI Services RBAC roles](https://learn.microsoft.com/en-us/azure/ai-services/authentication)
- [Disable local authentication on Cognitive Services](https://learn.microsoft.com/en-us/azure/ai-services/disable-local-auth)
