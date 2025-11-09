# Container App Environment and Container App Module
# This module provides Container App Environment with optional Hello World demo app

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
    azapi = {
      source  = "Azure/azapi"
      version = ">= 1.0"
    }
  }
}

# Get current client configuration
data "azurerm_client_config" "current" {}

# ----------------------------------------------------------------------------------------------------------
# Container App Environment using azapi_resource
# ----------------------------------------------------------------------------------------------------------
resource "azapi_resource" "container_app_environment" {
  type      = "Microsoft.App/managedEnvironments@2024-03-01"
  name      = var.container_app_environment_name
  location  = var.location
  parent_id = "/subscriptions/${data.azurerm_client_config.current.subscription_id}/resourceGroups/${var.resource_group_name}"

  # Disable schema validation to allow managed identity configuration
  schema_validation_enabled = false

  # Add managed identity configuration
  identity {
    type = "SystemAssigned"
  }

  body = {
    properties = {
      # VNet configuration for private networking
      vnetConfiguration = var.infrastructure_subnet_id != null ? {
        infrastructureSubnetId = var.infrastructure_subnet_id
        internal              = var.internal_load_balancer_enabled
      } : null

      # App logs configuration - supports cross-subscription Log Analytics  
      # Disabled due to API validation issues with cross-subscription setup. 
      # Manually enable in Azure portal and remove ContainerAppConsoleLogs, AppEnvSpringAppConsoleLogs, and AppEnvSessionConsoleLogs in Azure Monitor Diagnostics Settings for CAE
      appLogsConfiguration = null

      # Workload profiles configuration
      workloadProfiles = concat(
        # Always include Consumption profile
        [{
          name                = "Consumption"
          workloadProfileType = "Consumption"
        }],
        # Conditionally add dedicated workload profile
        var.enable_dedicated_workload_profiles ? [{
          name                = var.dedicated_workload_profile_name
          workloadProfileType = var.dedicated_workload_profile_type
          minimumCount       = var.dedicated_workload_profile_min_count
          maximumCount       = var.dedicated_workload_profile_max_count
        }] : []
      )

      # Zone redundancy
      zoneRedundant = false
    }
  }

  tags = var.tags

  # Response export to access computed values
  response_export_values = ["*"]
}

# ----------------------------------------------------------------------------------------------------------
# Demo Container App (Hello World)
# ----------------------------------------------------------------------------------------------------------
resource "azurerm_container_app" "helloworld" {
  count                        = var.deploy_helloworld_app ? 1 : 0
  name                         = var.container_app_name
  container_app_environment_id = azapi_resource.container_app_environment.id
  resource_group_name          = var.resource_group_name
  revision_mode                = "Single"
  workload_profile_name        = var.enable_dedicated_workload_profiles ? var.dedicated_workload_profile_name : "Consumption"
  tags                         = var.tags

  identity {
    type = "SystemAssigned"
  }

  template {
    container {
      name   = var.container_app_container_name
      image  = var.container_app_image
      cpu    = var.container_app_cpu
      memory = var.container_app_memory

      # Environment variables for demo app
      dynamic "env" {
        for_each = var.container_app_env_vars
        content {
          name        = env.value.name
          value       = env.value.value
          secret_name = env.value.secret_name
        }
      }
    }

    min_replicas = var.container_app_min_replicas
    max_replicas = var.container_app_max_replicas
  }

  # Secrets for demo app
  dynamic "secret" {
    for_each = var.container_app_secrets
    content {
      name  = secret.value.name
      value = secret.value.value
    }
  }

  # Ingress configuration
  dynamic "ingress" {
    for_each = var.enable_ingress ? [1] : []
    content {
      allow_insecure_connections = var.ingress_allow_insecure_connections
      external_enabled           = var.ingress_external_enabled
      target_port                = var.ingress_target_port

      traffic_weight {
        percentage      = 100
        latest_revision = true
      }
    }
  }

  depends_on = [azapi_resource.container_app_environment]
}

# ----------------------------------------------------------------------------------------------------------
# Diagnostic Settings for Container App Environment
# ----------------------------------------------------------------------------------------------------------
resource "azurerm_monitor_diagnostic_setting" "container_app_environment" {
  count                      = var.log_analytics_workspace_customer_id != null ? 1 : 0
  name                       = "diag-${var.container_app_environment_name}"
  target_resource_id         = azapi_resource.container_app_environment.id
  log_analytics_workspace_id = var.log_analytics_workspace_id

  enabled_log {
    category = "ContainerAppSystemLogs"
  }

  enabled_log {
    category = "ContainerAppConsoleLogs"
  }

  enabled_log {
    category = "AppEnvSpringAppConsoleLogs"
  }

  enabled_log {
    category = "AppEnvSessionConsoleLogs"
  }

  enabled_log {
    category = "AppEnvSessionPoolEventLogs"
  }

  enabled_log {
    category = "AppEnvSessionLifeCycleLogs"
  }

  depends_on = [azapi_resource.container_app_environment]
}

# ----------------------------------------------------------------------------------------------------------
# Role Assignment for Container App Environment Managed Identity
# ----------------------------------------------------------------------------------------------------------
resource "azurerm_role_assignment" "container_env_log_analytics" {
  count                = var.log_analytics_workspace_id != null ? 1 : 0
  scope                = var.log_analytics_workspace_id
  role_definition_name = "Log Analytics Contributor"
  principal_id         = azapi_resource.container_app_environment.identity[0].principal_id
  principal_type       = "ServicePrincipal"
  
  depends_on = [azapi_resource.container_app_environment]
}
