terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.19.0"
    }
    azapi = {
      source  = "Azure/azapi"
    }
  }
}

# Data source for current Azure client configuration
data "azurerm_client_config" "current" {}

# Azure AI Services (Cognitive Services with CognitiveServices kind)
# resource "azapi_resource.ai_foundry_project" "this" {
#   name                = var.cognitive_name
#   location            = var.location
#   resource_group_name = var.resource_group_name
#   kind                = "AIServices"
#   sku_name            = "S0"
  
#   identity {
#     type = "SystemAssigned"
#   }
#   public_network_access_enabled = var.public_network_access_enabled
#   custom_subdomain_name         = lower(var.cognitive_name)
# }

resource "azapi_resource" "ai_foundry_account" {
  type                      = "Microsoft.CognitiveServices/accounts@2025-06-01"
  name                      = var.cognitive_name
  #parent_id                 = azurerm_resource_group.rg.id
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"
  location                  = var.location
  schema_validation_enabled = false
  tags = var.tags
  body = {
    kind = "AIServices"
    sku  = { name = "S0" }
    identity = { type = "SystemAssigned" }
    properties = {
      disableLocalAuth      = false
      allowProjectManagement = true
      customSubDomainName   = lower(var.cognitive_name)
      publicNetworkAccess   = var.public_network_access_enabled ? "Enabled" : "Disabled"
    }
  }
}

# AI Foundry Project as a Cognitive Services sub-resource
resource "azapi_resource" "ai_foundry_project" {
  count     = var.create_ai_foundry_project ? 1 : 0
  type      = "Microsoft.CognitiveServices/accounts/projects@2025-04-01-preview"
  name      = "${var.cognitive_name}-project"
  #location  = "westus3"  #testing to see if we can have two prj with different location from parent AI Foundry
  location  = var.location
  parent_id = azapi_resource.ai_foundry_account.id  # This makes it a sub-resource
  tags = var.tags
  body = {
    properties = {
      displayName = var.project_display_name != "" ? var.project_display_name : "${var.cognitive_name} AI Foundry Project"
      description = var.project_description != "" ? var.project_description : "AI Foundry project for ${var.cognitive_name}"
    }
    identity = {
      type = "SystemAssigned"
    }
  }

  depends_on = [azapi_resource.ai_foundry_account]
}

resource "azurerm_cognitive_deployment" "deployment" {
  # Only create deployments if create_deployments is true and deployments list is not empty
  for_each = var.create_deployments && length(var.deployments) > 0 ? { for dep in var.deployments : dep.model.name => dep if try(dep.model.name, null) != null } : {}
  
  name                 = each.value.name
  cognitive_account_id = azapi_resource.ai_foundry_account.id
  rai_policy_name      = try(each.value.model.rai_policy_name, null)

  model {
    format  = each.value.model.format
    name    = each.value.model.name
    version = each.value.model.version
  }
  
  sku {
    name     = each.value.sku.name
    capacity = each.value.sku.capacity
  }

  depends_on = [
    azapi_resource.ai_foundry_account
  ]
}

# RBAC: Grant current user Azure AI User role
resource "azurerm_role_assignment" "current_user_azure_ai_user" {
  count                = var.assign_current_user_admin ? 1 : 0
  scope                = azapi_resource.ai_foundry_account.id
  role_definition_name = "Azure AI Administrator"  #Needed to deploy models
  principal_id         = var.current_user_object_id
  principal_type       = "User"

  depends_on = [azapi_resource.ai_foundry_account]
}