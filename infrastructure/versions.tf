terraform {
  required_version = ">= 1.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "azure/azapi"
      version = ">= 1.0"
    }
  }
}

provider "azurerm" {
  features {}
  resource_provider_registrations = "core"
  storage_use_azuread             = true
  subscription_id                 = "ac844b56-6818-4eb6-9ae7-2454ceb83c47"
}

provider "azapi" {
  # Default azapi provider
}

# Provider alias for Log Analytics workspace in different subscription
# Only used when existing_log_analytics_subscription_id is specified
provider "azurerm" {
  alias           = "log_analytics_subscription"
  subscription_id = var.existing_log_analytics_subscription_id != "" ? var.existing_log_analytics_subscription_id : null
  features {}
  resource_provider_registrations = "core"
}

provider "azapi" {
  alias           = "log_analytics_subscription"
  subscription_id = var.existing_log_analytics_subscription_id != "" ? var.existing_log_analytics_subscription_id : null
}

# Provider alias for existing AI Foundry account in a different subscription
provider "azapi" {
  alias           = "existing_ai_foundry_subscription"
  subscription_id = var.existing_ai_foundry_subscription_id != "" ? var.existing_ai_foundry_subscription_id : null
}