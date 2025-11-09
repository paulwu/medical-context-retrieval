# Container App Environment Module

This module creates an Azure Container Apps Environment with comprehensive security features including system-assigned managed identity, diagnostic settings, and role-based access control (RBAC) integration.

## Features

- **Container App Environment**: Provides the runtime environment for Container Apps
- **System-Assigned Managed Identity**: Enables secure access to other Azure services
- **Comprehensive Logging**: Diagnostic settings with all 6 log categories enabled
- **Cross-Subscription Log Analytics**: Support for cross-subscription workspace integration
- **RBAC Integration**: Automatic role assignments for secure service access
- **Workload Profiles**: Supports both Consumption and Dedicated workload profiles
- **Private Networking**: Supports VNet integration with internal load balancer
- **Demo Container App**: Optional Hello World application for testing

## Usage

### Basic Usage

```hcl
module "container_app_environment" {
  source = "../Modules/container_app_environment"

  container_app_environment_name = "my-container-env"
  location                      = "West US 3"
  resource_group_name           = "my-resource-group"
  
  tags = {
    Environment = "Development"
    Project     = "MyProject"
  }
}
```

### With Managed Identity and Cross-Subscription Logging

```hcl
module "container_app_environment" {
  source = "../Modules/container_app_environment"

  container_app_environment_name    = "my-container-env"
  location                         = "West US 3"
  resource_group_name              = "my-resource-group"
  infrastructure_subnet_id         = "/subscriptions/.../subnets/container-apps-subnet"
  internal_load_balancer_enabled   = true
  enable_dedicated_workload_profiles = true
  
  # Cross-subscription Log Analytics integration
  log_analytics_workspace_customer_id = "workspace-customer-id"
  log_analytics_workspace_shared_key = "workspace-shared-key" # sensitive
  log_analytics_workspace_id = "/subscriptions/other-sub/.../workspaces/workspace"
  
  tags = {
    Environment = "Development"
    Project     = "MyProject"
  }
}

# RBAC assignments (typically managed at root level)
resource "azurerm_role_assignment" "container_env_kv_access" {
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.container_app_environment.container_app_environment_identity_principal_id
}

resource "azurerm_role_assignment" "container_env_acr_pull" {
  scope                = azurerm_container_registry.main.id
  role_definition_name = "AcrPull"
  principal_id         = module.container_app_environment.container_app_environment_identity_principal_id
}
```

### With Hello World Demo App

```hcl
module "container_app_environment" {
  source = "../Modules/container_app_environment"

  container_app_environment_name = "my-container-env"
  location                      = "West US 3"
  resource_group_name           = "my-resource-group"
  
  # Deploy demo app
  deploy_helloworld_app = true
  container_app_name    = "hello-world"
  
  # Environment variables for demo app
  container_app_env_vars = [
    {
      name  = "COSMOS_DB_ENDPOINT"
      value = "https://my-cosmos.documents.azure.com:443/"
    },
    {
      name        = "COSMOS_DB_KEY"
      secret_name = "cosmos-db-key"
    }
  ]
  
  # Secrets for demo app
  container_app_secrets = [
    {
      name  = "cosmos-db-key"
      value = "your-cosmos-key-here"
    }
  ]
  
  tags = {
    Environment = "Development"
    Project     = "MyProject"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| azurerm | ~> 4.0 |

## Resources Created

- `azapi_resource` - The Container Apps Environment with system-assigned managed identity
- `azurerm_monitor_diagnostic_setting` - Diagnostic settings for comprehensive logging
- `azurerm_role_assignment` - Log Analytics Contributor role for cross-subscription logging
- `azurerm_container_app` - Optional Hello World demo application

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| container_app_environment_name | Name of the Container App Environment | `string` | n/a | yes |
| location | Azure region for the resources | `string` | n/a | yes |
| resource_group_name | Name of the resource group | `string` | n/a | yes |
| infrastructure_subnet_id | Subnet ID for Container Apps infrastructure | `string` | `null` | no |
| internal_load_balancer_enabled | Enable internal load balancer for private networking | `bool` | `false` | no |
| log_analytics_workspace_customer_id | The customer ID (GUID) of the Log Analytics workspace | `string` | `null` | no |
| log_analytics_workspace_shared_key | The shared key of the Log Analytics workspace | `string` | `null` | no |
| log_analytics_workspace_id | The resource ID of the Log Analytics workspace for diagnostic settings | `string` | `null` | no |
| enable_dedicated_workload_profiles | Enable dedicated workload profiles (required for private networking) | `bool` | `false` | no |
| deploy_helloworld_app | Deploy the Hello World demo container app | `bool` | `false` | no |
| container_app_name | Name of the Container App | `string` | `"helloworld-app"` | no |
| container_app_image | Container image to deploy | `string` | `"nginxdemos/hello:latest"` | no |

## Outputs

| Name | Description |
|------|-------------|
| container_app_environment_id | ID of the Container App Environment |
| container_app_environment_name | Name of the Container App Environment |
| container_app_environment_identity_principal_id | Principal ID of the Container App Environment managed identity |
| container_app_environment_identity_tenant_id | Tenant ID of the Container App Environment managed identity |
| container_app_id | ID of the Container App (if deployed) |
| container_app_fqdn | FQDN of the Container App (if deployed) |
| container_app_url | URL of the Container App (if deployed) |

## Notes

- **System-Assigned Managed Identity**: Automatically enabled for secure access to Azure services
- **Comprehensive Logging**: All 6 log categories enabled via diagnostic settings:
  - ContainerAppSystemLogs, ContainerAppConsoleLogs
  - AppEnvSpringAppConsoleLogs, AppEnvSessionConsoleLogs  
  - AppEnvSessionPoolEventLogs, AppEnvSessionLifeCycleLogs
- **Cross-Subscription Support**: Handles Log Analytics workspaces in different subscriptions
- **RBAC Ready**: Outputs managed identity principal ID for role assignments
- When using private networking (`internal_load_balancer_enabled = true`), you must also set `enable_dedicated_workload_profiles = true`
- The Hello World demo app is optional and controlled by the `deploy_helloworld_app` variable
- Role assignments (Key Vault, ACR, Cosmos DB) are typically managed at the root level to avoid circular dependencies
- For production use, consider enabling purge protection and other security features
