# Variables for Key Vault Module

variable "key_vault_name" {
  description = "Name of the Key Vault"
  type        = string
}

variable "location" {
  description = "Azure region for the Key Vault"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "tenant_id" {
  description = "Azure tenant ID"
  type        = string
}

variable "key_vault_sku" {
  description = "SKU name for the Key Vault"
  type        = string
  default     = "standard"
}

variable "soft_delete_retention_days" {
  description = "Number of days to retain deleted keys"
  type        = number
  default     = 7
}

variable "purge_protection_enabled" {
  description = "Whether purge protection is enabled"
  type        = bool
  default     = false
}
variable "certificate_contact_email" {
  description = "Email address for certificate contacts"
  type        = string
  default     = ""
}

variable "certificate_contact_name" {
  description = "Name for certificate contacts"
  type        = string
  default     = ""
}

variable "certificate_contact_phone" {
  description = "Phone number for certificate contacts"
  type        = string
  default     = ""
}

variable "enabled_for_disk_encryption" {
  description = "Whether the Key Vault is enabled for disk encryption"
  type        = bool
  default     = true
}

variable "enabled_for_template_deployment" {
  description = "Whether the Key Vault is enabled for template deployment"
  type        = bool
  default     = true
}

variable "enable_rbac_authorization" {
  description = "Whether to use Azure RBAC for authorization"
  type        = bool
  default     = true
}

variable "current_user_object_id" {
  description = "Object ID of the current user for RBAC assignment"
  type        = string
}

variable "openai_identity_principal_id" {
  description = "Principal ID of the OpenAI service identity (optional)"
  type        = string
  default     = null
}

variable "assign_current_user_admin" {
  description = "Whether to assign current user as Key Vault Administrator"
  type        = bool
  default     = true
}

variable "assign_openai_permissions" {
  description = "Whether to assign OpenAI service permissions"
  type        = bool
  default     = false
}

variable "tags" {
  description = "Tags to apply to the Key Vault"
  type        = map(string)
  default     = {}
}

variable "public_network_access_enabled" {
  description = "Whether public network access is enabled for the Key Vault"
  type        = bool
  default     = true
}
