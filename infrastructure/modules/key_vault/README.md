# Key Vault Module

This module creates an Azure Key Vault with RBAC-based authorization and optional role assignments for users and services.

## Features

- Creates Azure Key Vault with configurable settings
- Uses Azure RBAC for authorization (recommended approach)
- Optional role assignments for current user and OpenAI service
- Configurable soft delete and purge protection settings
- Support for disk encryption enablement

## Usage

```hcl
module "key_vault" {
  source = "./Modules/key_vault"

  key_vault_name        = "my-keyvault-name"
  location              = "West US 3"
  resource_group_name   = "my-resource-group"
  tenant_id             = data.azurerm_client_config.current.tenant_id
  current_user_object_id = data.azurerm_client_config.current.object_id
  
  # Optional: Grant OpenAI service access
  assign_openai_permissions    = true
  openai_identity_principal_id = azapi_resource.ai_foundry_project.openai.identity[0].principal_id

  tags = {
    Environment = "production"
    Team        = "platform"
  }
}
```

## Variables

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| key_vault_name | Name of the Key Vault | `string` | n/a | yes |
| location | Azure region for the Key Vault | `string` | n/a | yes |
| resource_group_name | Name of the resource group | `string` | n/a | yes |
| tenant_id | Azure tenant ID | `string` | n/a | yes |
| current_user_object_id | Object ID of the current user for RBAC assignment | `string` | n/a | yes |
| key_vault_sku | SKU name for the Key Vault | `string` | `"standard"` | no |
| soft_delete_retention_days | Number of days to retain deleted keys | `number` | `7` | no |
| purge_protection_enabled | Whether purge protection is enabled | `bool` | `false` | no |
| enabled_for_disk_encryption | Whether the Key Vault is enabled for disk encryption | `bool` | `true` | no |
| enable_rbac_authorization | Whether to use Azure RBAC for authorization | `bool` | `true` | no |
| openai_identity_principal_id | Principal ID of the OpenAI service identity (optional) | `string` | `null` | no |
| assign_current_user_admin | Whether to assign current user as Key Vault Administrator | `bool` | `true` | no |
| assign_openai_permissions | Whether to assign OpenAI service permissions | `bool` | `false` | no |
| tags | Tags to apply to the Key Vault | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| key_vault_id | ID of the Key Vault |
| key_vault_name | Name of the Key Vault |
| key_vault_uri | URI of the Key Vault (sensitive) |
| key_vault_tenant_id | Tenant ID of the Key Vault |
| key_vault_sku_name | SKU name of the Key Vault |
| key_vault_access_policy | Access policy configuration for reference |

## RBAC Roles Assigned

When enabled, this module assigns the following Azure RBAC roles:

- **Key Vault Administrator**: Assigned to the current user (if `assign_current_user_admin` is true)
- **Key Vault Secrets User**: Assigned to OpenAI service identity (if `assign_openai_permissions` is true)
- **Key Vault Crypto User**: Assigned to OpenAI service identity (if `assign_openai_permissions` is true)

## Requirements

- Terraform >= 1.0
- AzureRM Provider >= 3.0
- Azure CLI authenticated with appropriate permissions

## Notes

- The Key Vault uses RBAC authorization by default (recommended over access policies)
- Soft delete is enabled with configurable retention period
- Purge protection is disabled by default but can be enabled for production environments
- The module supports both standalone usage and integration with AI services
