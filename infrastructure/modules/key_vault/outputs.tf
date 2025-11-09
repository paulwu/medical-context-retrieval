# Key Vault Module Outputs

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = azurerm_key_vault.main.id
}

output "key_vault_name" {
  description = "Name of the Key Vault"
  value       = azurerm_key_vault.main.name
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = azurerm_key_vault.main.vault_uri
  sensitive   = true
}

output "key_vault_tenant_id" {
  description = "Tenant ID of the Key Vault"
  value       = azurerm_key_vault.main.tenant_id
}

output "key_vault_sku_name" {
  description = "SKU name of the Key Vault"
  value       = azurerm_key_vault.main.sku_name
}

output "key_vault_access_policy" {
  description = "Access policy configuration (for reference)"
  value = {
    enable_rbac_authorization   = azurerm_key_vault.main.enable_rbac_authorization
    enabled_for_disk_encryption = azurerm_key_vault.main.enabled_for_disk_encryption
    purge_protection_enabled    = azurerm_key_vault.main.purge_protection_enabled
    soft_delete_retention_days  = azurerm_key_vault.main.soft_delete_retention_days
  }
}
