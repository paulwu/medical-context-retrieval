# Infrastructure Deployment Guide

This directory contains Terraform configuration for deploying the medical context retrieval demo environment in Azure. The templates follow Azure Cloud Adoption Framework conventions and support staged rollouts of key components such as private networking, Azure Container Apps, Cosmos DB, and Azure AI Foundry.


## Prerequisites
- Terraform CLI 1.0 or later
- Azure CLI 2.59 or later with access to the target subscription
- Azure RBAC permissions on the target subscription/resource group:
   - `Contributor` to create and update Azure resources
   - `User Access Administrator` to assign role bindings for Key Vault, Container Registry, and other services 
   - `Role Based Access Control Administrator` for the ONEMTCWW-OMS resource group to assign role bindings for Log Analytics Workspace
   - `Azure AI Administrator` (or higher) to create AI Foundry accounts and projects
- Azure resource providers registered in the subscription:
   - `Microsoft.App` for Azure Container Apps (may not be registered by default)
   - `Microsoft.ContainerRegistry` for Azure Container Registry
   - `Microsoft.DocumentDB` for Cosmos DB (may not be registered by default)
   - `Microsoft.KeyVault`, `Microsoft.OperationalInsights`, `Microsoft.Network`, `Microsoft.Storage`, and `Microsoft.CognitiveServices`
- Optional: Service principal credentials if you prefer non-interactive authentication

## Authenticate to Azure
### Option 1: Azure CLI (interactive)
```bash
az login --use-device-code
az account set --subscription <subscription-id>

#az account set --subscription 04902013-de09-470f-9512-dc311d1d557a
az account set --subscription ac844b56-6818-4eb6-9ae7-2454ceb83c47
                              ac844b56-6818-4eb6-9ae7-2454ceb83c47
```
Terraform will re-use your CLI session.

### Option 2: Service principal (non-interactive)
Export the required environment variables before running Terraform:
```bash
export ARM_CLIENT_ID=<app-id>
export ARM_CLIENT_SECRET=<password>
export ARM_TENANT_ID=<tenant-id>
export ARM_SUBSCRIPTION_ID=<subscription-id>
```

If you prefer to re-use the currently logged-in Azure CLI context, populate the tenant and subscription IDs automatically:
```bash
export ARM_TENANT_ID=$(az account show --query tenantId -o tsv)
export ARM_SUBSCRIPTION_ID=$(az account show --query id -o tsv)
```

## Configure Deployment Variables
1. Copy the sample variable file and tailor it to your environment:
   ```bash
   cd infrastructure
   cp terraform.backup.vars terraform.tfvars
   ```
2. Update `terraform.tfvars` with the appropriate values:
   - `organization_prefix` and `environment` drive resource naming and must remain short.
   - `use_existing_log_analytics` toggles between a new or existing Log Analytics workspace.
   - `deploy_*` flags let you stage features (e.g., skip private networking or AI Foundry on first pass).
   - `aif_location1` must be a valid Azure region for Azure AI Foundry.
3. Keep the Terraform workspace (see next section) aligned with the `environment` variable.

## Initialize Terraform
Run the standard initialization from the `infrastructure` folder. Re-run whenever provider versions change.
```bash
terraform init
```
If you later add a remote backend, pass the required `-backend-config` settings here.

## Select a Terraform Workspace
Workspaces let you partition state per environment (dev, qa, prod, etc.). Ensure the workspace name matches your `environment` variable.
```bash
terraform workspace select <env> || terraform workspace new <env>
```
Example for QA:
```bash
terraform workspace select qa || terraform workspace new qa
```

## Plan Changes
Review the execution plan before applying.
```bash
terraform plan -out=tfplan
```
To use a custom variable file, append `-var-file=<path>`.

## Apply Changes
Provision or update the Azure resources.
```bash
terraform apply

terraform apply -auto-approve

```
Use `-auto-approve` in automation scenarios only.

## Destroy (Optional)
Tear down the deployed resources when they are no longer needed.
```bash
terraform destroy
```
For selective cleanup (e.g., keep AI Foundry accounts), adjust the `destroy_ai_foundry_instances` and other toggle variables instead of destroying the whole stack.

## Post-Deployment Manual Step
Azure Container Apps requires a managed identity assignment to write diagnostics to Log Analytics. After the first deployment, run the following (replace placeholders with real values):
```bash
az containerapp env identity assign --name <container-app-env-name> --resource-group <resource-group>
az role assignment create \
  --assignee $(az containerapp env show --name <container-app-env-name> --resource-group <resource-group> --query "identity.principalId" -o tsv) \
  --role "Log Analytics Contributor" \
  --scope /subscriptions/<log-analytics-subscription-id>/resourceGroups/<log-analytics-rg>/providers/Microsoft.OperationalInsights/workspaces/<workspace-name>
```

## Troubleshooting Tips
- Re-run `terraform init` if you switch Azure subscriptions or upgrade providers.
- If planning fails due to authentication, confirm the Azure CLI context or service principal variables.
- When using an existing Log Analytics workspace in a different subscription, ensure your account has Reader access to that subscription and the `log_analytics_subscription_id` is populated.
- For private networking errors, verify that the selected regions support Container Apps with internal environments and private endpoints.
