# Zava Voice Demo Terraform Configuration
# Following Azure Cloud Adoption Framework (CAF) best practices

# Data sources for current client configuration
data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}

# - Log Analytics Workspace --------------------------------------------------------------------------------
#   In our demo Tenant, we have to use an existing LAW in a different subscription. To enable that:
#    Set variable use_existing_log_analytics to true
#    Set variable log_analytics_subscription_id to the ID of the subscription containing the existing LAW
# ----------------------------------------------------------------------------------------------------------
# Data source for existing Log Analytics workspace (same subscription)
data "azurerm_log_analytics_workspace" "existing_same_sub" {
  count               = var.use_existing_log_analytics && var.log_analytics_subscription_id == "" ? 1 : 0
  name                = var.existing_log_analytics_workspace_name
  resource_group_name = var.existing_log_analytics_resource_group_name
}

# Data source for existing Log Analytics workspace (different subscription)
data "azurerm_log_analytics_workspace" "existing_diff_sub" {
  count               = var.use_existing_log_analytics && var.log_analytics_subscription_id != "" ? 1 : 0
  provider            = azurerm.log_analytics_subscription
  name                = var.existing_log_analytics_workspace_name
  resource_group_name = var.existing_log_analytics_resource_group_name
}

# Get Log Analytics workspace shared keys using azapi (same subscription)
data "azapi_resource_action" "log_analytics_keys_same_sub" {
  count       = var.use_existing_log_analytics && var.log_analytics_subscription_id == "" ? 1 : 0
  type        = "Microsoft.OperationalInsights/workspaces@2022-10-01"
  resource_id = data.azurerm_log_analytics_workspace.existing_same_sub[0].id
  action      = "sharedKeys"
  method      = "POST"
}

# Get Log Analytics workspace shared keys using azapi (different subscription)
data "azapi_resource_action" "log_analytics_keys_diff_sub" {
  count       = var.use_existing_log_analytics && var.log_analytics_subscription_id != "" ? 1 : 0
  provider    = azapi.log_analytics_subscription
  type        = "Microsoft.OperationalInsights/workspaces@2022-10-01"
  resource_id = data.azurerm_log_analytics_workspace.existing_diff_sub[0].id
  action      = "sharedKeys"
  method      = "POST"
}

# ----------------------------------------------------------------------------------------------------------
# Create new Log Analytics Workspace
# ----------------------------------------------------------------------------------------------------------
# resource "azurerm_log_analytics_workspace" "main" {
#   count               = var.deploy_infrastructure ? 1 : 0
#   name                = local.log_analytics_name
#   location            = local.main_location
#   resource_group_name = azurerm_resource_group.zava_demo[0].name
#   sku                 = var.log_analytics_sku
#   retention_in_days   = var.log_analytics_retention_days
#   tags                = local.common_tags

#   depends_on = [azurerm_resource_group.zava_demo]
# }


# ----------------------------------------------------------------------------------------------------------
# 1) Resource Group for Zava Voice Demo
# ----------------------------------------------------------------------------------------------------------
resource "azurerm_resource_group" "zava_demo" {
  count    = var.deploy_infrastructure ? 1 : 0
  name     = local.rg_zava_demo
  location = local.main_location
  tags = merge(local.common_tags, {
    RGMonthlyCost = "500"
  })
}

# ----------------------------------------------------------------------------------------------------------
# 2) Application Insights
# ----------------------------------------------------------------------------------------------------------
resource "azurerm_application_insights" "main" {
  count               = var.deploy_infrastructure ? 1 : 0
  name                = local.application_insights_name
  location            = local.main_location
  resource_group_name = azurerm_resource_group.zava_demo[0].name
  application_type    = "web"
  workspace_id = var.use_existing_log_analytics ? (
    var.log_analytics_subscription_id != "" ?
    data.azurerm_log_analytics_workspace.existing_diff_sub[0].id :
    data.azurerm_log_analytics_workspace.existing_same_sub[0].id
  ) : null
  tags = merge(local.common_tags, {
    RGMonthlyCost = "10"
  })

  depends_on = [azurerm_resource_group.zava_demo]
}

# ----------------------------------------------------------------------------------------------------------
# 3) Private Network Module (VNet, Private Endpoints, Private DNS Zones)
# ----------------------------------------------------------------------------------------------------------
locals {
  # Base private endpoints that are only created when private networking is deployed
  base_private_endpoints = var.deploy_infrastructure && var.deploy_private_network ? merge({
    storage = {
      name                           = "pe-${local.storage_account_name}"
      private_connection_resource_id = azurerm_storage_account.main[0].id
      subresource_names              = ["blob"]
      private_dns_zone_name          = "privatelink.blob.core.windows.net"
    }
    keyvault = {
      name                           = "pe-${module.key_vault[0].key_vault_name}"
      private_connection_resource_id = module.key_vault[0].key_vault_id
      subresource_names              = ["vault"]
      private_dns_zone_name          = "privatelink.vaultcore.azure.net"
    }
    cosmosdb = {
      name                           = "pe-${local.cosmos_db_name}"
      private_connection_resource_id = azurerm_cosmosdb_account.main[0].id
      subresource_names              = ["sql"]
      private_dns_zone_name          = "privatelink.documents.azure.com"
    }
    # cognitive_services = {
    #   name                           = "pe-${local.cognitive_services_name}"
    #   private_connection_resource_id = module.cognitive_services[0].id
    #   subresource_names              = ["account"]
    #   private_dns_zone_name          = "privatelink.cognitiveservices.azure.com"
    # }
    container_registry = {
      name                           = "pe-${local.container_registry_name}"
      private_connection_resource_id = azurerm_container_registry.main[0].id
      subresource_names              = ["registry"]
      private_dns_zone_name          = "privatelink.azurecr.io"
    }
    }, var.deploy_container_app_environment ? {
    container_app_environment = {
      name                           = "pe-${local.container_app_environment_name}"
      private_connection_resource_id = module.container_app_environment[0].container_app_environment_id
      subresource_names              = ["managedEnvironments"]
      private_dns_zone_name          = "privatelink.azurecontainerapps.io"
    }
  } : {}) : {}

  # Conditional AI Foundry private endpoints - only create when modules exist and private networking is enabled
  aifoundry_private_endpoints = var.deploy_infrastructure && var.deploy_private_network && var.deploy_ai_foundry_instances && !var.destroy_ai_foundry_instances ? {
    aifoundry1 = {
      name                           = "pe-${local.aifoundry_account1_name}"
      private_connection_resource_id = module.aifoundry_1[0].ai_foundry_account_id
      subresource_names              = ["account"]
      private_dns_zone_name          = "privatelink.cognitiveservices.azure.com"
    }
    aifoundry2 = {
      name                           = "pe-${local.aifoundry_account2_name}"
      private_connection_resource_id = module.aifoundry_2[0].ai_foundry_account_id
      subresource_names              = ["account"]
      private_dns_zone_name          = "privatelink.cognitiveservices.azure.com"
    }
  } : {}

  # Merge all private endpoints - only non-empty when private networking is deployed
  all_private_endpoints = merge(
    local.base_private_endpoints,
    local.aifoundry_private_endpoints
  )
}

module "private_network" {
  count  = var.deploy_infrastructure && var.deploy_private_network ? 1 : 0
  source = "../Modules/private_network"

  resource_group_name = azurerm_resource_group.zava_demo[0].name
  location            = local.main_location
  vnet_name           = local.vnet_name
  vnet_address_space  = ["10.240.0.0/16"]

  subnets = {
    container_apps_infra = {
      name             = "snet-containerapps-infra"
      address_prefixes = ["10.240.0.0/23"] # /23 recommended for Container Apps (properly aligned)
      delegation = {
        name = "container-apps-delegation"
        service_delegation = {
          name = "Microsoft.App/environments"
          actions = [
            "Microsoft.Network/virtualNetworks/subnets/action"
          ]
        }
      }
    }
    private_endpoints = {
      name              = "snet-private-endpoints"
      address_prefixes  = ["10.240.2.0/24"]
      service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.CognitiveServices"]
    }
  }

  private_endpoints = local.all_private_endpoints

  tags = local.common_tags

  depends_on = [
    azurerm_resource_group.zava_demo,
    azurerm_storage_account.main,
    azurerm_cosmosdb_account.main,
    module.key_vault
  ]
}

# ----------------------------------------------------------------------------------------------------------
# 4) Storage Account
# ----------------------------------------------------------------------------------------------------------
resource "azurerm_storage_account" "main" {
  count                         = var.deploy_infrastructure ? 1 : 0
  name                          = local.storage_account_name
  resource_group_name           = azurerm_resource_group.zava_demo[0].name
  location                      = local.main_location
  account_tier                  = var.storage_account_tier
  account_replication_type      = var.storage_account_replication_type
  min_tls_version               = "TLS1_2"
  public_network_access_enabled = var.deploy_private_network ? false : true
  tags = merge(local.common_tags, {
    RGMonthlyCost = "60"
  })

  identity {
    type = "SystemAssigned"
  }
  depends_on = [azurerm_resource_group.zava_demo]
}
# ----------------------------------------------------------------------------------------------------------
# 5) Container Registry for AI Hub
# ----------------------------------------------------------------------------------------------------------
resource "azurerm_container_registry" "main" {
  count               = var.deploy_infrastructure ? 1 : 0
  name                = local.container_registry_name
  resource_group_name = azurerm_resource_group.zava_demo[0].name
  location            = local.main_location
  sku                 = var.deploy_private_network ? "Premium" : var.container_registry_sku
  admin_enabled       = var.container_registry_admin_enabled
  tags = merge(local.common_tags, {
    RGMonthlyCost = var.deploy_private_network ? "50" : "20"
  })

  identity {
    type = "SystemAssigned"
  }
  depends_on = [azurerm_resource_group.zava_demo]
}


# ----------------------------------------------------------------------------------------------------------
# 6) Cosmos DB Account
# ----------------------------------------------------------------------------------------------------------
resource "azurerm_cosmosdb_account" "main" {
  count                         = var.deploy_infrastructure ? 1 : 0
  name                          = local.cosmos_db_name
  location                      = local.main_location
  resource_group_name           = azurerm_resource_group.zava_demo[0].name
  offer_type                    = "Standard"
  kind                          = "GlobalDocumentDB"
  public_network_access_enabled = var.deploy_private_network ? false : true
  tags = merge(local.common_tags, {
    RGMonthlyCost = "50"
  })

  consistency_policy {
    consistency_level       = var.cosmos_db_consistency_level
    max_interval_in_seconds = 300
    max_staleness_prefix    = 100000
  }

  geo_location {
    location          = local.main_location
    failover_priority = 0
  }

  depends_on = [azurerm_resource_group.zava_demo]
}

# ----------------------------------------------------------------------------------------------------------
#    Cosmos DB SQL Database - sustineo2
# ----------------------------------------------------------------------------------------------------------
resource "azurerm_cosmosdb_sql_database" "sustineo2" {
  count               = var.deploy_infrastructure ? 1 : 0
  name                = var.cosmos_db_database_id
  resource_group_name = azurerm_resource_group.zava_demo[0].name
  account_name        = azurerm_cosmosdb_account.main[0].name

  depends_on = [azurerm_cosmosdb_account.main]
}

# ----------------------------------------------------------------------------------------------------------
#    Cosmos DB SQL Containers - Dynamic creation from array
# ----------------------------------------------------------------------------------------------------------
resource "azurerm_cosmosdb_sql_container" "containers" {
  for_each = var.deploy_infrastructure ? {
    for container in var.cosmos_db_containers :
    container.name => container
  } : {}

  name                = each.value.name
  resource_group_name = azurerm_resource_group.zava_demo[0].name
  account_name        = azurerm_cosmosdb_account.main[0].name
  database_name       = each.value.database_name != null ? each.value.database_name : azurerm_cosmosdb_sql_database.sustineo2[0].name
  partition_key_paths = [each.value.partition_key]
  throughput          = each.value.throughput

  depends_on = [azurerm_cosmosdb_sql_database.sustineo2]
}

# ----------------------------------------------------------------------------------------------------------
# 7) Container App Environment Module
# ----------------------------------------------------------------------------------------------------------
module "container_app_environment" {
  count  = var.deploy_infrastructure && var.deploy_container_app_environment ? 1 : 0
  source = "../Modules/container_app_environment"

  container_app_environment_name     = local.container_app_environment_name
  location                           = local.main_location
  resource_group_name                = azurerm_resource_group.zava_demo[0].name
  infrastructure_subnet_id           = var.deploy_private_network ? module.private_network[0].subnet_ids["container_apps_infra"] : null
  internal_load_balancer_enabled     = var.deploy_private_network ? true : false
  enable_dedicated_workload_profiles = var.deploy_private_network ? true : false
  tags = merge(local.common_tags, {
    RGMonthlyCost = var.deploy_private_network ? "370" : "15"
  })

  # Configure with existing Log Analytics workspace customer ID
  log_analytics_workspace_customer_id = var.use_existing_log_analytics ? (
    var.log_analytics_subscription_id != "" ?
    data.azurerm_log_analytics_workspace.existing_diff_sub[0].workspace_id :
    data.azurerm_log_analytics_workspace.existing_same_sub[0].workspace_id
  ) : null

  # Configure with existing Log Analytics workspace shared key
  log_analytics_workspace_shared_key = var.use_existing_log_analytics ? (
    var.log_analytics_subscription_id != "" ?
    try(jsondecode(data.azapi_resource_action.log_analytics_keys_diff_sub[0].output).primarySharedKey, null) :
    try(jsondecode(data.azapi_resource_action.log_analytics_keys_same_sub[0].output).primarySharedKey, null)
  ) : null

  # Configure Log Analytics workspace resource ID for diagnostic settings
  log_analytics_workspace_id = var.use_existing_log_analytics ? (
    var.log_analytics_subscription_id != "" ?
    data.azurerm_log_analytics_workspace.existing_diff_sub[0].id :
    data.azurerm_log_analytics_workspace.existing_same_sub[0].id
  ) : null

  # Deploy Hello World demo app
  deploy_helloworld_app      = var.deploy_container_app_helloworld
  container_app_name         = local.container_app_name
  container_app_image        = var.container_app_image
  container_app_cpu          = var.container_app_cpu
  container_app_memory       = var.container_app_memory
  container_app_min_replicas = var.container_app_min_replicas
  container_app_max_replicas = var.container_app_max_replicas
  ingress_target_port        = var.container_app_target_port

  # Environment variables for demo app
  container_app_env_vars = var.deploy_container_app_helloworld ? [
    {
      name  = "COSMOS_DB_ENDPOINT"
      value = azurerm_cosmosdb_account.main[0].endpoint
    },
    {
      name        = "COSMOS_DB_KEY"
      secret_name = "cosmos-db-key"
    },
    {
      name  = "STORAGE_ACCOUNT_NAME"
      value = azurerm_storage_account.main[0].name
    }
  ] : []

  # Secrets for demo app
  container_app_secrets = var.deploy_container_app_helloworld ? [
    {
      name  = "cosmos-db-key"
      value = azurerm_cosmosdb_account.main[0].primary_key
    }
  ] : []

  depends_on = [
    azurerm_resource_group.zava_demo,
    data.azurerm_log_analytics_workspace.existing_same_sub,
    data.azurerm_log_analytics_workspace.existing_diff_sub,
    azurerm_cosmosdb_account.main,
    azurerm_storage_account.main
  ]
}

# RBAC: Grant Container App Environment permissions to the Log Analytics workspace
# Note: Container App Environments need managed identity enabled via Azure CLI
# 
# Manual steps needed after deployment:
# 1. Enable system-assigned managed identity:
#    az containerapp env identity assign --name "zava-qa-cae" --resource-group "zava-qa" --system-assigned
# 2. Grant Log Analytics Contributor role:
#    az role assignment create \
#      --assignee $(az containerapp env show --name "zava-qa-cae" --resource-group "zava-qa" --query "identity.principalId" -o tsv) \
#      --role "Log Analytics Contributor" \
#      --scope "/subscriptions/595a74d5-5d8a-421d-b364-979ba24a6489/resourceGroups/onemtcww-oms/providers/Microsoft.OperationalInsights/workspaces/onemtcww"

# ----------------------------------------------------------------------------------------------------------
# 9) Key Vault Module
# ----------------------------------------------------------------------------------------------------------
module "key_vault" {
  count  = var.deploy_infrastructure ? 1 : 0
  source = "../Modules/key_vault"

  key_vault_name                  = local.key_vault_name
  location                        = local.main_location
  resource_group_name             = azurerm_resource_group.zava_demo[0].name
  tenant_id                       = data.azurerm_client_config.current.tenant_id
  current_user_object_id          = data.azurerm_client_config.current.object_id
  key_vault_sku                   = var.key_vault_sku
  soft_delete_retention_days      = 7
  purge_protection_enabled        = false # enable in production
  enabled_for_disk_encryption     = true
  enabled_for_template_deployment = true
  enable_rbac_authorization       = true
  public_network_access_enabled   = var.deploy_private_network ? false : true
  assign_current_user_admin       = true
  assign_openai_permissions       = false # Disabled since OpenAI is now managed through AI Foundry modules
  openai_identity_principal_id    = null  # Disabled since OpenAI is now managed through AI Foundry modules
  certificate_contact_email       = var.key_vault_certificate_contact_email
  certificate_contact_name        = var.key_vault_certificate_contact_name
  certificate_contact_phone       = var.key_vault_certificate_contact_phone
  tags = merge(local.common_tags, {
    RGMonthlyCost = "10"
  })


  depends_on = [
    azurerm_resource_group.zava_demo
  ]
}

# ----------------------------------------------------------------------------------------------------------
# 10) AI Foundry 1 in WestUS3
# ----------------------------------------------------------------------------------------------------------
module "aifoundry_1" {
  count                         = var.deploy_infrastructure && var.deploy_ai_foundry_instances && !var.destroy_ai_foundry_instances ? 1 : 0
  source                        = "../Modules/ai_foundry"
  resource_group_name           = azurerm_resource_group.zava_demo[0].name
  location                      = var.aif_location1
  cognitive_name                = local.aifoundry_account1_name
  assign_current_user_admin     = true
  current_user_object_id        = data.azurerm_client_config.current.object_id
  public_network_access_enabled = var.deploy_private_network ? false : true
  create_deployments            = var.deploy_ai_model_deployments
  create_ai_foundry_project     = true # Now enabled - creates proper Cognitive Services project
  tags = merge(local.common_tags, {
    RGMonthlyCost = "50"
  })

  deployments = var.deploy_ai_model_deployments ? [
    {
      name = "gpt-4o-mini"
      model = {
        format          = "OpenAI"
        name            = "gpt-4o-mini"
        version         = "2024-07-18"
        rai_policy_name = "Microsoft.Default"
      }
      sku = {
        name     = "GlobalStandard"
        capacity = 250
      }
    }
    # {
    #   name = "gpt-image-1"
    #   model = {
    #     format          = "OpenAI"
    #     name            = "gpt-image-1"
    #     version         = "2025-04-15"
    #     rai_policy_name = "Microsoft.Default"
    #   }
    #   sku = {
    #     name     = "GlobalStandard"
    #     capacity = 3
    #   }
    # }
  ] : []

  depends_on = [
    azurerm_resource_group.zava_demo
  ]
}

# Terraform moved blocks to handle transition from non-count to count resources
moved {
  from = module.aifoundry_1
  to   = module.aifoundry_1[0]
}

# ----------------------------------------------------------------------------------------------------------
# 11) AI Foundry 2 - Secondary Foundry
# ----------------------------------------------------------------------------------------------------------
module "aifoundry_2" {
  count                         = var.deploy_infrastructure && !var.destroy_ai_foundry_instances ? 1 : 0
  source                        = "../Modules/ai_foundry"
  resource_group_name           = azurerm_resource_group.zava_demo[0].name
  location                      = var.aif_location2
  cognitive_name                = local.aifoundry_account2_name
  assign_current_user_admin     = true
  current_user_object_id        = data.azurerm_client_config.current.object_id
  public_network_access_enabled = var.deploy_private_network ? false : true
  create_deployments            = true
  #create_deployments            = var.deploy_ai_model_deployments
  create_ai_foundry_project = true
  tags = merge(local.common_tags, {
    RGMonthlyCost = "50"
  })

  deployments = var.deploy_ai_model_deployments ? [
    # {
    #   name = "gpt-4o-mini-realtime-preview"
    #   model = {
    #     format          = "OpenAI"
    #     name            = "gpt-4o-mini-realtime-preview"
    #     version         = "2024-12-17"
    #     rai_policy_name = "Microsoft.Default"
    #   }
    #   sku = {
    #     name     = "GlobalStandard"
    #     capacity = 6
    #   }
    # },
    {
      name = "gpt-image-1"
      model = {
        format          = "OpenAI"
        name            = "gpt-image-1"
        version         = "2025-04-15"
        rai_policy_name = "Microsoft.Default"
      }
      sku = {
        name     = "GlobalStandard"
        capacity = 3
      }
    },
    {
      name = "sora"
      model = {
        format          = "OpenAI"
        name            = "sora"
        version         = "2025-05-02"
        rai_policy_name = "Microsoft.Default"
      }
      sku = {
        name     = "GlobalStandard"
        capacity = 60
      }
    }
  ] : []

  depends_on = [
    azurerm_resource_group.zava_demo
  ]
}

moved {
  from = module.aifoundry_2
  to   = module.aifoundry_2[0]
}

# ----------------------------------------------------------------------------------------------------------
# 13) Azure Front Door
#     Azure Front Door for Container App protection. If Container App Environment is deployed, create Front Door to protect it.
# ----------------------------------------------------------------------------------------------------------
module "azure_frontdoor" {
  source = "../Modules/azure_frontdoor"
  count  = var.deploy_infrastructure && var.deploy_container_app_environment ? 1 : 0

  profile_name        = "${local.resource_prefix}-frontdoor"
  resource_group_name = azurerm_resource_group.zava_demo[0].name
  sku_name            = "Standard_AzureFrontDoor"
  endpoint_name       = "${local.resource_prefix}-fd-endpoint"
  origin_host_name    = var.deploy_container_app_helloworld ? module.container_app_environment[0].container_app_fqdn : "yourapp.azurecontainerapps.io"
  #origin_host_name   = azurerm_container_app.main[0].latest_revision_fqdn
  health_probe_path = "/"
  origin_protocol   = "Https"
  tags = merge(local.common_tags, {
    RGMonthlyCost = var.deploy_private_network ? "400" : "125"
  })
  depends_on = [module.container_app_environment, azurerm_resource_group.zava_demo]
}

# ----------------------------------------------------------------------------------------------------------
# 14) Grant the necessary permissions
# ----------------------------------------------------------------------------------------------------------

# ----------------------------------------------------------------------------------------------------------
# Key Vault Secrets User Role Assignment for Container Apps Environment
# ----------------------------------------------------------------------------------------------------------
resource "azurerm_role_assignment" "container_app_env_kv_secrets_user" {
  count                = var.deploy_infrastructure && var.deploy_container_app_environment ? 1 : 0
  scope                = module.key_vault[0].key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.container_app_environment[0].container_app_environment_identity_principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [
    module.key_vault,
    module.container_app_environment
  ]
}

# ----------------------------------------------------------------------------------------------------------
# AcrPull Role Assignment for Container Apps Environment
# ----------------------------------------------------------------------------------------------------------
resource "azurerm_role_assignment" "container_app_env_acr_pull" {
  count                = var.deploy_infrastructure && var.deploy_container_app_environment ? 1 : 0
  scope                = azurerm_container_registry.main[0].id
  role_definition_name = "AcrPull"
  principal_id         = module.container_app_environment[0].container_app_environment_identity_principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [
    azurerm_container_registry.main,
    module.container_app_environment
  ]
}

# ----------------------------------------------------------------------------------------------------------
# Cosmos DB Account Reader Role Assignment for Container Apps Environment
# ----------------------------------------------------------------------------------------------------------
resource "azurerm_role_assignment" "container_app_env_cosmos_reader" {
  count                = var.deploy_infrastructure && var.deploy_container_app_environment ? 1 : 0
  scope                = azurerm_cosmosdb_account.main[0].id
  role_definition_name = "Cosmos DB Account Reader Role"
  principal_id         = module.container_app_environment[0].container_app_environment_identity_principal_id
  principal_type       = "ServicePrincipal"

  depends_on = [
    azurerm_cosmosdb_account.main,
    module.container_app_environment
  ]
}

# ----------------------------------------------------------------------------------------------------------
# 12) Cognitive Services (Multi-Service Account)
# ----------------------------------------------------------------------------------------------------------
# module "cognitive_services" {
#   count  = var.deploy_infrastructure ? 1 : 0
#   source = "../Modules/cognitive_services"

#   cognitive_name                = local.cognitive_services_name
#   resource_group_name           = azurerm_resource_group.zava_demo[0].name
#   location                      = local.main_location
#   sku_name                      = "S0"
#   public_network_access_enabled = var.deploy_private_network ? false : true
#   custom_subdomain_name         = local.cognitive_services_subdomain

#   network_acls = var.deploy_private_network ? {
#     default_action        = "Deny"
#     ip_rules              = []
#     virtual_network_rules = []
#   } : null

#   tags = local.common_tags

#   depends_on = [
#     azurerm_resource_group.zava_demo
#   ]
# }


# Azure Front Door Profile
# resource "azurerm_cdn_frontdoor_profile" "main" {
#   count               = var.deploy_infrastructure ? 1 : 0
#   name                = "${local.resource_prefix}-afd"
#   resource_group_name = azurerm_resource_group.zava_demo[0].name
#   sku_name            = "Standard_AzureFrontDoor"
#   tags                = local.common_tags
# }

# Azure Front Door Endpoint
# resource "azurerm_cdn_frontdoor_endpoint" "main" {
#   count                    = var.deploy_infrastructure ? 1 : 0
#   name                     = "${local.resource_prefix}-afd-endpoint"
#   cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main[0].id
#   tags                     = local.common_tags
# }

# Azure Front Door Origin Group
# resource "azurerm_cdn_frontdoor_origin_group" "main" {
#   count                    = var.deploy_infrastructure ? 1 : 0
#   name                     = "containerapp-origin-group"
#   cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.main[0].id

#   load_balancing {
#     sample_size                 = 4
#     successful_samples_required = 3
#   }

#   health_probe {
#     path                = "/"
#     request_type        = "HEAD"
#     protocol            = "Https"
#     interval_in_seconds = 100
#   }
# }

# Azure Front Door Origin
# resource "azurerm_cdn_frontdoor_origin" "main" {
#   count                         = var.deploy_infrastructure ? 1 : 0
#   name                          = "containerapp-origin"
#   cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.main[0].id

#   enabled                        = true
#   certificate_name_check_enabled = true
#   host_name                      = azurerm_container_app.main[0].latest_revision_fqdn
#   http_port                      = 80
#   https_port                     = 443
#   origin_host_header             = azurerm_container_app.main[0].latest_revision_fqdn
#   priority                       = 1
#   weight                         = 1000
# }

# Azure Front Door Route
# resource "azurerm_cdn_frontdoor_route" "main" {
#   count                         = var.deploy_infrastructure ? 1 : 0
#   name                          = "containerapp-route"
#   cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.main[0].id
#   cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.main[0].id
#   enabled                       = true

#   forwarding_protocol    = "HttpsOnly"
#   https_redirect_enabled = true
#   patterns_to_match      = ["/*"]
#   supported_protocols    = ["Http", "Https"]

#   cdn_frontdoor_origin_ids = [azurerm_cdn_frontdoor_origin.main[0].id]
#   link_to_default_domain   = true
# }


