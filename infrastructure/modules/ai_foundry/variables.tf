variable "cognitive_name" {}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "West US 3"
}

variable "deployments" {
  description = "List of AI model deployments to create"
  type        = list(any)
  default     = []
}

variable "create_deployments" {
  description = "Whether to create AI model deployments (allows separating AI Service creation from model deployment)"
  type        = bool
  default     = true
}

variable "public_network_access_enabled" {
  description = "Whether public network access is enabled for the AI service"
  type        = bool
  default     = false
}

variable "create_ai_foundry_project" {
  description = "Whether to create an AI Foundry project for this AI service"
  type        = bool
  default     = true
}

variable "project_display_name" {
  description = "Display name for the AI Foundry project"
  type        = string
  default     = ""
}

variable "project_description" {
  description = "Description for the AI Foundry project"
  type        = string
  default     = ""
}

variable "tags" {
  description = "Tags to apply to the Key Vault"
  type        = map(string)
  default     = {}
}
variable "assign_current_user_admin" {
  description = "Whether to assign current user as Key Vault Administrator"
  type        = bool
  default     = true
}

variable "current_user_object_id" {
  description = "Object ID of the current user for RBAC assignment"
  type        = string
}

# variable "resource_group_id" {}
# variable "cognitive_kind" {
#   default = "OpenAI"
# }
# variable "cognitive_sku" {
#   default = "S0"
# }

# variable "cognitive_private_endpoint_name" {}
# variable "virtual_network_name" {}
# variable "virtual_network_resource_group_name" {}
# variable "private_endpoints_subnet_name" {}
# variable "private_dns_zone_resource_group_name" {}
# variable "private_dns_zone_name" {
#   default = "privatelink.openai.azure.com"
# }
# variable "tags" {
#   default = {}
# }
