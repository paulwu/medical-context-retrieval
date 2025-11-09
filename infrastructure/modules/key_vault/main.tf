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
  network_acls {
    default_action = "Allow"  # Temporarily allow all access during deployment
    bypass         = "AzureServices"

    # Add your current IP if needed
    # ip_rules = ["YOUR_PUBLIC_IP"]
    ip_rules = ["68.4.116.145"] # Your current public IP
  }

  timeouts {
    create = "10m"
    read   = "5m"
    update = "10m"
    delete = "10m"
  }
  tags = var.tags
}
# Certificate Contacts for the Key Vault - Temporarily disabled during network configuration
# resource "azurerm_key_vault_certificate_contacts" "main" {
#   key_vault_id = azurerm_key_vault.main.id

#   contact {
#     email = var.certificate_contact_email
#     name  = var.certificate_contact_name != "" ? var.certificate_contact_name : "Key Vault Administrator"
#     phone = var.certificate_contact_phone != "" ? var.certificate_contact_phone : null
#   }

#   # Explicit dependencies to ensure RBAC is applied first
#   depends_on = [
#     azurerm_key_vault.main,
#     azurerm_role_assignment.current_user_kv_admin
#   ]
#   # Add timeouts to handle propagation delays
#   timeouts {
#     create = "10m"
#     read   = "5m"
#     update = "10m"
#     delete = "10m"
#   }
# }

# RBAC: Grant current user Key Vault Administrator role
resource "azurerm_role_assignment" "current_user_kv_admin" {
  count                = var.assign_current_user_admin ? 1 : 0
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Administrator"
  principal_id         = var.current_user_object_id
  principal_type       = "User"

  depends_on = [azurerm_key_vault.main]
}

# RBAC: Grant OpenAI service Key Vault Secrets User role
resource "azurerm_role_assignment" "openai_kv_secrets_user" {
  count                = var.assign_openai_permissions && var.openai_identity_principal_id != null ? 1 : 0
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = var.openai_identity_principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_key_vault.main]
}

# RBAC: Grant OpenAI service Key Vault Crypto User role
resource "azurerm_role_assignment" "openai_kv_crypto_user" {
  count                = var.assign_openai_permissions && var.openai_identity_principal_id != null ? 1 : 0
  scope                = azurerm_key_vault.main.id
  role_definition_name = "Key Vault Crypto User"
  principal_id         = var.openai_identity_principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [azurerm_key_vault.main]
}
