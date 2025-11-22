# Quick Start Guide for running the demo in EXP
We have created a home in the EXP tenant to house the application. Step 1 is already completed. Follow step 2 and 3 if you want to update the application. Please check with the project owners before making changes. The current version of the application require careful manual coordination when multiple developers are involved.

## 1. Create the Azure resources
The `/infrastructure` folder contains the Terraform code for deploying the resources. See the `/infstruture/ReadMe.md` for more details.

> **Heads up:** The Container App demo requires an Azure OpenAI API key. If `deploy_ai_foundry_instances` is set to `false`, either set `use_existing_ai_foundry_project=true` with `existing_ai_foundry_id` pointing to the Cognitive Services account you want to reuse, provide an existing Key Vault secret ID through `azure_openai_api_key_secret_id`, or supply the key directly via `azure_openai_api_key` in your `terraform.tfvars`. Terraform now validates this requirement and will stop with a helpful error if the key is missing when the demo app is enabled.

Recommended workflow:
- Update `infrastructure/terraform.tfvars` with the correct subscription IDs, resource IDs, and Azure OpenAI configuration (either deploy a new AI Foundry instance or reuse an existing account as noted above).
- Run `terraform -chdir=infrastructure init` (first use only), `terraform -chdir=infrastructure plan`, then `terraform -chdir=infrastructure apply` to create or update the Azure resources. The plan/apply steps now handle wiring the Container App secrets to Key Vault automatically.


## 2. Create a Package
After the resources are deployed using Terrform, run `bash package.sh` to create a container package using the instructions contained in the `Dockerfile` and publish it to the Azure Container Registry created by the Terraform script.

When completed successfuly, you'll see something like the following:

```text
2025/11/20 07:38:43 Successfully pushed image: medctxdemoacr.azurecr.io/medical-context-rag:latest
2025/11/20 07:38:43 Step ID: build marked as successful (elapsed time in seconds: 95.386247)
2025/11/20 07:38:43 Populating digests for step ID: build...
2025/11/20 07:38:45 Successfully populated digests for step ID: build
2025/11/20 07:38:45 Step ID: push marked as successful (elapsed time in seconds: 44.987580)
2025/11/20 07:38:45 The following dependencies were found:
2025/11/20 07:38:45 
- image:
    registry: medctxdemoacr.azurecr.io
    repository: medical-context-rag
    tag: 20251120-073132
    digest: sha256:77fa0ea5fe16eb50c32f7c1880197e5f6c314786c0effbcba6bf42f6b206b20c
  runtime-dependency:
    registry: registry.hub.docker.com
    repository: library/python
    tag: 3.11-slim
    digest: sha256:8ef21a26e7c342e978a68cf2d6b07627885930530064f572f432ea422a8c0907
  git: {}
.
.
.
.
.

  git: {}

Run ID: ch4 was successful after 2m35s
Image build complete.
Summary:
  Registry : medctxdemoacr.azurecr.io
  Image    : medical-context-rag
  Tags     : 20251120-073132, latest

To roll out the new revision:
  terraform -chdir=infrastructure plan output=tfplan 
  terraform -chdir=infrastructure apply
    or
  az containerapp update --name medctx-demo-ca --resource-group EXP-HLS-MedicalContext-RG --image medctxdemoacr.azurecr.io/medical-context-rag:latest
    or
  bash update.sh

```
The Terraform script in step 1 creates an Azure Container App instance hosting a starter 'hello world' application. Make sure the application is working properly before moving to step 3.


## 3. Update deployment Package
Once the package is created and published, run `bash update.sh' to update the container app instance.

When completed successfuly, you'll see something like the following:

```text
Ensuring Container App 'medctx-demo-ca' has registry access to 'medctxdemoacr.azurecr.io'...
WARNING: Updating existing registry.
Updating Container App 'medctx-demo-ca' in resource group 'EXP-HLS-MedicalContext-RG' to image 'medctxdemoacr.azurecr.io/medical-context-rag:latest'...
{
  "id": "/subscriptions/ac844b56-6818-4eb6-9ae7-2454ceb83c47/resourceGroups/EXP-HLS-MedicalContext-RG/providers/Microsoft.App/containerapps/medctx-demo-ca",
  "identity": {
    "principalId": "95ac1e5c-d483-4ec7-901d-1bf3f6090e31",
    "tenantId": "32dc2feb-7716-4cf8-b1a6-f02cf37fd6bf",
    "type": "SystemAssigned"
  },
  "location": "East US 2",
  "name": "medctx-demo-ca",
  "properties": {
.
.
.
.
  "type": "Microsoft.App/containerApps"
}
Update complete.

```

## Post Update configuration
The Container App instance require a few more steps for the application to work.
1. Navigate to the Container App instance (medctx-demo-ca) in the Azure Portal
2. Navigate to Application > Containers > Properties. Verify the container "demo-app" is pointed to Azure Container Registry `medctxdemoacr.azurecr.io` with the image `medical-context-rag`
3. Under the `Environment variables` tab, confirm "AZURE_OPENAI_ENDPOINT" points to the correct endpoint and that "AZURE_OPENAI_API_KEY" is sourced from the Key Vault secret `azure-openai-api-key`. Terraform populates these values automatically—only adjust if you intentionally need a different endpoint.
4. Navigate to Networking > Ingress blade. Make sure the 'Ingress' box is checked and change the Target port to `8866` (default to port 80).
5. Navigate to the 'Overview' blade of the container app. Restart the container app by clicking [Stop] to stop the Container App and then [Start] to initiate the application again.
6. While you are in the 'Overview' blade, capture the Application url for later use.
6. Navigate to Monitoring > Log stream
