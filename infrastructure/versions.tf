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
}

provider "azapi" {
  # Default azapi provider
}

# Provider alias for Log Analytics workspace in different subscription
# Only used when log_analytics_subscription_id is specified
provider "azurerm" {
  alias           = "log_analytics_subscription"
  subscription_id = var.log_analytics_subscription_id != "" ? var.log_analytics_subscription_id : null
  features {}
  resource_provider_registrations = "core"
}

provider "azapi" {
  alias           = "log_analytics_subscription"
  subscription_id = var.log_analytics_subscription_id != "" ? var.log_analytics_subscription_id : null
}