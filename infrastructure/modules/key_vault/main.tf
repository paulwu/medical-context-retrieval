# Key Vault Module - Main Configuration

# Key Vault for AI Hub (using Azure RBAC)
resource "azurerm_key_vault" "main" {
  name                            = var.key_vault_name
  location                        = var.location
  resource_group_name             = var.resource_group_name
  enabled_for_disk_encryption     = var.enabled_for_disk_encryption
  enabled_for_template_deployment = var.enabled_for_template_deployment
  tenant_id                       = var.tenant_id
  soft_delete_retention_days      = var.soft_delete_retention_days
  purge_protection_enabled        = var.purge_protection_enabled
  sku_name                        = var.key_vault_sku
  enable_rbac_authorization       = var.enable_rbac_authorization
  public_network_access_enabled   = var.public_network_access_enabled

  # Network ACLs to allow access during deployment
  # NOTE: default_action = "Allow" permits all traffic, making ip_rules redundant.
  # Change default_action to "Deny" when ip_rules should take effect.
  network_acls {
    default_action = "Allow"
    bypass         = "AzureServices"
    ip_rules       = var.network_acl_ip_rules
  }

  timeouts {
    create = "10m"
    read   = "5m"
    update = "10m"
    delete = "10m"
  }
  tags = var.tags
}
# RBAC: Grant current user Key Vault Administrator role
resource "azurerm_role_assignment" "current_user_kv_admin" {
  count                = var.assign_current_user_admin ? 1 : 0
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.current_user_object_id
  principal_type       = "User"

}

# RBAC: Grant OpenAI service Key Vault Secrets User role
resource "azurerm_role_assignment" "openai_kv_secrets_user" {
  count                = var.assign_openai_permissions && var.openai_identity_principal_id != null ? 1 : 0
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.openai_identity_principal_id
  principal_type       = "ServicePrincipal"

}

# RBAC: Grant OpenAI service Key Vault Crypto User role
resource "azurerm_role_assignment" "openai_kv_crypto_user" {
  count                = var.assign_openai_permissions && var.openai_identity_principal_id != null ? 1 : 0
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Crypto User"
  principal_id         = var.openai_identity_principal_id
  principal_type       = "ServicePrincipal"

}
