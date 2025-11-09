# ---------------------------------------------------------------------------------------------------
# Core Configuration Variables
# ---------------------------------------------------------------------------------------------------
variable "environment" {
  description = "The environment name (e.g., dev, qa, prod, jp)"
  type        = string
  default     = "dev"

  validation {
    condition     = can(regex("^(dev|qa|prod|jp)$", var.environment))
    error_message = "Environment must be one of: dev, qa, prod, jp."
  }
}

variable "organization_prefix" {
  description = "Organization prefix for resource naming (e.g., contoso, myorg)"
  type        = string

  validation {
    condition     = can(regex("^[A-Za-z0-9]{2,9}$", var.organization_prefix))
    error_message = "Organization prefix must be 2-9 characters, uppercase or lowercase alphanumeric only."
  }
}

variable "location" {
  description = "The Azure region where resources will be created"
  type        = string
  default     = "West US 3"
}

variable "additional_tags" {
  description = "Additional tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# ---------------------------------------------------------------------------------------------------
# Deployment Switches
# ---------------------------------------------------------------------------------------------------

variable "deploy_infrastructure" {
  description = "Whether to deploy base infrastructure (Resource Group, Storage, Network, Key Vault, etc.)"
  type        = bool
  default     = true
}

variable "deploy_private_network" {
  description = "Whether to deploy the private network module (VNet, private endpoints, private DNS zones). Use false for Stage 1, true for Stage 2 to avoid circular dependencies."
  type        = bool
  default     = true
}

variable "deploy_ai_model_deployments" {
  description = "Whether to deploy AI model deployments in AI Foundry (separate from AI Foundry instance creation)"
  type        = bool
  default     = true
}

variable "deploy_ai_foundry_instances" {
  description = "Whether to create NEW AI Foundry service instances. Set to false for subsequent deployments to preserve existing instances."
  type        = bool
  default     = true
}

variable "deploy_container_app_environment" {
  description = "Whether to deploy the Container App Environment and related resources"
  type        = bool
  default     = true
}

variable "deploy_container_app_helloworld" {
  description = "Whether to deploy the Hello World demo container app"
  type        = bool
  default     = true
}

variable "destroy_ai_foundry_instances" {
  description = "Whether to destroy AI Foundry service instances. Set to true ONLY when you want to remove them completely."
  type        = bool
  default     = false
}

# Sora Model Configuration
variable "deploy_sora_model" {
  description = "Whether to deploy Sora video generation model (requires preview access)"
  type        = bool
  default     = false
}

# DALL-E-3 Model Configuration
variable "deploy_gpt_image_model" {
  description = "Whether to deploy DALL-E-3 image generation model"
  type        = bool
  default     = true
}

# GPT-4o-mini-realtime-preview Model Configuration
variable "deploy_gpt4o_mini_realtime" {
  description = "Whether to deploy GPT-4o-mini-realtime-preview model"
  type        = bool
  default     = true
}

# GPT-4 Model deployment removed - using AI Foundry modules instead

# ---------------------------------------------------------------------------------------------------
# AI Foundry Variables
# ---------------------------------------------------------------------------------------------------
variable "aif_location1" {
  type        = string
  description = "Azure region"
}
variable "aif_location2" {
  type        = string
  description = "Azure region"
}

# ---------------------------------------------------------------------------------------------------
# Container App Configuration
# ---------------------------------------------------------------------------------------------------
variable "container_app_image" {
  description = "Container image for the Container App"
  type        = string
  default     = "mcr.microsoft.com/azuredocs/containerapps-helloworld:latest"
}

variable "container_app_cpu" {
  description = "CPU allocation for the container"
  type        = number
  default     = 0.25

  validation {
    condition     = contains([0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0], var.container_app_cpu)
    error_message = "Container App CPU must be one of: 0.25, 0.5, 0.75, 1.0, 1.25, 1.5, 1.75, 2.0."
  }
}

variable "container_app_memory" {
  description = "Memory allocation for the container"
  type        = string
  default     = "0.5Gi"

  validation {
    condition     = contains(["0.5Gi", "1Gi", "1.5Gi", "2Gi", "2.5Gi", "3Gi", "3.5Gi", "4Gi"], var.container_app_memory)
    error_message = "Container App memory must be one of: 0.5Gi, 1Gi, 1.5Gi, 2Gi, 2.5Gi, 3Gi, 3.5Gi, 4Gi."
  }
}

variable "container_app_min_replicas" {
  description = "Minimum number of replicas for the Container App"
  type        = number
  default     = 1

  validation {
    condition     = var.container_app_min_replicas >= 0 && var.container_app_min_replicas <= 25
    error_message = "Container App minimum replicas must be between 0 and 25."
  }
}

variable "container_app_max_replicas" {
  description = "Maximum number of replicas for the Container App"
  type        = number
  default     = 10

  validation {
    condition     = var.container_app_max_replicas >= 1 && var.container_app_max_replicas <= 25
    error_message = "Container App maximum replicas must be between 1 and 25."
  }
}

variable "container_app_target_port" {
  description = "Target port for the Container App ingress"
  type        = number
  default     = 80

  validation {
    condition     = var.container_app_target_port >= 1 && var.container_app_target_port <= 65535
    error_message = "Container App target port must be between 1 and 65535."
  }
}
# Container Registry Configuration
variable "container_registry_sku" {
  description = "SKU for Azure Container Registry"
  type        = string
  default     = "Basic"

  validation {
    condition     = contains(["Basic", "Standard", "Premium"], var.container_registry_sku)
    error_message = "Container Registry SKU must be one of: Basic, Standard, Premium."
  }
}

variable "container_registry_admin_enabled" {
  description = "Whether admin user is enabled for Container Registry"
  type        = bool
  default     = true
}

# ---------------------------------------------------------------------------------------------------
# Cosmos DB Configuration
# ---------------------------------------------------------------------------------------------------
variable "cosmos_db_consistency_level" {
  description = "Consistency level for Cosmos DB"
  type        = string
  default     = "Session"

  validation {
    condition     = contains(["Eventual", "ConsistentPrefix", "Session", "BoundedStaleness", "Strong"], var.cosmos_db_consistency_level)
    error_message = "Cosmos DB consistency level must be one of: Eventual, ConsistentPrefix, Session, BoundedStaleness, Strong."
  }
}

variable "cosmos_db_throughput" {
  description = "Throughput for Cosmos DB database (RU/s)"
  type        = number
  default     = 400

  validation {
    condition     = var.cosmos_db_throughput >= 400 && var.cosmos_db_throughput <= 1000000
    error_message = "Cosmos DB throughput must be between 400 and 1,000,000 RU/s."
  }
}

variable "cosmos_db_database_id" {
  description = "Database ID for the Cosmos DB"
  type        = string
  default     = "sustineo" // Zava Voice demo app expects the database ID to be 'sustineo'
}

# Container configuration replaced with cosmos_db_containers array
# variable "cosmos_db_container_id" - REMOVED: Using array-based container configuration
# variable "cosmos_db_container_partition_key" - REMOVED: Using array-based container configuration

# New array-based container configuration
variable "cosmos_db_containers" {
  description = "List of Cosmos DB containers to create"
  type = list(object({
    name          = string
    partition_key = string
    throughput    = number
    database_name = optional(string, null) # Optional, will use default database if not specified
  }))
  default = [
    {
      name          = "VoiceConfiguration"
      partition_key = "/id"
      throughput    = 400
    },
    {
      name          = "DesignConfigurations"
      partition_key = "/id"
      throughput    = 400
    }
  ]
}

# ---------------------------------------------------------------------------------------------------
# Key Vault
# ---------------------------------------------------------------------------------------------------
variable "key_vault_sku" {
  description = "SKU for Azure Key Vault"
  type        = string
  default     = "standard"

  validation {
    condition     = contains(["standard", "premium"], var.key_vault_sku)
    error_message = "Key Vault SKU must be either 'standard' or 'premium'."
  }
}

variable "key_vault_certificate_contact_email" {
  description = "Email address for certificate contacts"
  type        = string
  default     = ""
}

variable "key_vault_certificate_contact_name" {
  description = "Name for certificate contacts"
  type        = string
  default     = ""
}

variable "key_vault_certificate_contact_phone" {
  description = "Phone number for certificate contacts"
  type        = string
  default     = ""
}

# ---------------------------------------------------------------------------------------------------
# Log Analytics
# ---------------------------------------------------------------------------------------------------
variable "use_existing_log_analytics" {
  description = "Whether to use an existing Log Analytics workspace"
  type        = bool
  default     = true
}

variable "existing_log_analytics_workspace_name" {
  description = "Name of the existing Log Analytics workspace"
  type        = string
  default     = ""
}

variable "existing_log_analytics_resource_group_name" {
  description = "Resource group name of the existing Log Analytics workspace"
  type        = string
  default     = ""
}

variable "log_analytics_subscription_id" {
  description = "Subscription ID where the Log Analytics workspace is located (leave empty if same subscription)"
  type        = string
  default     = ""
}

variable "log_analytics_sku" {
  description = "SKU for Log Analytics Workspace"
  type        = string
  default     = "PerGB2018"

  validation {
    condition     = contains(["Free", "Standard", "Premium", "PerNode", "PerGB2018", "Standalone"], var.log_analytics_sku)
    error_message = "Invalid Log Analytics SKU specified."
  }
}

variable "log_analytics_retention_days" {
  description = "Number of days to retain logs in Log Analytics"
  type        = number
  default     = 90

  validation {
    condition     = var.log_analytics_retention_days >= 30 && var.log_analytics_retention_days <= 730
    error_message = "Log Analytics retention must be between 30 and 730 days."
  }
}

# ---------------------------------------------------------------------------------------------------
# Storage Account
# ---------------------------------------------------------------------------------------------------
variable "storage_account_tier" {
  description = "Performance tier for the storage account"
  type        = string
  default     = "Standard"

  validation {
    condition     = contains(["Standard", "Premium"], var.storage_account_tier)
    error_message = "Storage account tier must be either 'Standard' or 'Premium'."
  }
}

variable "storage_account_replication_type" {
  description = "Replication type for the storage account"
  type        = string
  default     = "LRS"

  validation {
    condition     = contains(["LRS", "GRS", "RAGRS", "ZRS", "GZRS", "RAGZRS"], var.storage_account_replication_type)
    error_message = "Storage account replication type must be one of: LRS, GRS, RAGRS, ZRS, GZRS, RAGZRS."
  }
}

# ===================================================================================================
# Landing Zone / Hub & Spoke Variables - REMOVED
# These variables were designed for a hub-and-spoke architecture but are not used in the current
# Zava demo implementation. The current architecture uses a single VNet with Container Apps integration.
# ===================================================================================================
# All hub & spoke variables removed to reduce configuration complexity

