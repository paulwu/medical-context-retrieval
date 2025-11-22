# Medical Context Retrieval Demo Infrastructure
# This deploys the AI models required by the dmeo

# Data sources for current client configuration
data "azurerm_client_config" "current" {}
data "azuread_client_config" "current" {}

# - Log Analytics Workspace --------------------------------------------------------------------------------
#   In EXP, we have to use an existing LAW in a different subscription. To enable that:
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
#   resource_group_name = azurerm_resource_group..project_main_new[0].name
#   sku                 = "PerGB2018"
#   retention_in_days   = 90
#   tags                = local.common_tags

#   depends_on = [azurerm_resource_group..project_main_new]
# }


# ----------------------------------------------------------------------------------------------------------
# 1) Resource Group for project - Create new or use existing
# ----------------------------------------------------------------------------------------------------------

# Data source for existing resource group
data "azurerm_resource_group" "project_main_existing" {
  count = var.deploy_infrastructure && var.use_existing_resource_group ? 1 : 0
  name  = var.existing_resource_group_name
}

# Create new resource group
resource "azurerm_resource_group" "project_main_new" {
  count    = var.deploy_infrastructure && !var.use_existing_resource_group ? 1 : 0
  name     = local.rg_project_main
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
  location            = local.resource_group_location
  resource_group_name = local.resource_group_name
  application_type    = "web"
  workspace_id = var.use_existing_log_analytics ? (
    var.log_analytics_subscription_id != "" ?
    data.azurerm_log_analytics_workspace.existing_diff_sub[0].id :
    data.azurerm_log_analytics_workspace.existing_same_sub[0].id
  ) : null
  tags = merge(local.common_tags, {
    RGMonthlyCost = "10"
  })

  depends_on = [
    azurerm_resource_group.project_main_new,
    data.azurerm_resource_group.project_main_existing
  ]
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
    # aifoundry2 = {
    #   name                           = "pe-<secondary-aifoundry-name>"
    #   private_connection_resource_id = module.aifoundry_2[0].ai_foundry_account_id
    #   subresource_names              = ["account"]
    #   private_dns_zone_name          = "privatelink.cognitiveservices.azure.com"
    # }
  } : {}

  # Merge all private endpoints - only non-empty when private networking is deployed
  all_private_endpoints = merge(
    local.base_private_endpoints,
    local.aifoundry_private_endpoints
  )
}

module "private_network" {
  count  = var.deploy_infrastructure && var.deploy_private_network ? 1 : 0
  source = "./modules/private_network"

  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
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
    azurerm_resource_group.project_main_new,
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
  resource_group_name           = local.resource_group_name
  location                      = local.resource_group_location
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
  depends_on = [
    azurerm_resource_group.project_main_new,
    data.azurerm_resource_group.project_main_existing
  ]
}
# ----------------------------------------------------------------------------------------------------------
# 5) Container Registry for AI Hub
# ----------------------------------------------------------------------------------------------------------
resource "azurerm_container_registry" "main" {
  count               = var.deploy_infrastructure ? 1 : 0
  name                = local.container_registry_name
  resource_group_name = local.resource_group_name
  location            = local.resource_group_location
  sku                 = var.deploy_private_network ? "Premium" : var.container_registry_sku
  admin_enabled       = var.container_registry_admin_enabled
  tags = merge(local.common_tags, {
    RGMonthlyCost = var.deploy_private_network ? "50" : "20"
  })

  identity {
    type = "SystemAssigned"
  }
  depends_on = [
    azurerm_resource_group.project_main_new,
    data.azurerm_resource_group.project_main_existing
  ]
}


# ----------------------------------------------------------------------------------------------------------
# 6) Cosmos DB Account
# ----------------------------------------------------------------------------------------------------------
resource "azurerm_cosmosdb_account" "main" {
  count                         = var.deploy_infrastructure ? 1 : 0
  name                          = local.cosmos_db_name
  location                      = local.resource_group_location
  resource_group_name           = local.resource_group_name
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
    location          = local.resource_group_location
    failover_priority = 0
  }

  depends_on = [
    azurerm_resource_group.project_main_new,
    data.azurerm_resource_group.project_main_existing
  ]
}

# ----------------------------------------------------------------------------------------------------------
#    Cosmos DB SQL Database - medical-ctx-rag
# ----------------------------------------------------------------------------------------------------------
resource "azurerm_cosmosdb_sql_database" "default" {
  count               = var.deploy_infrastructure ? 1 : 0
  name                = var.cosmos_db_database_id
  resource_group_name = local.resource_group_name
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
  resource_group_name = local.resource_group_name
  account_name        = azurerm_cosmosdb_account.main[0].name
  database_name       = each.value.database_name != null ? each.value.database_name : azurerm_cosmosdb_sql_database.default[0].name
  partition_key_paths = [each.value.partition_key]
  throughput          = each.value.throughput

  depends_on = [azurerm_cosmosdb_sql_database.default]
}

# ----------------------------------------------------------------------------------------------------------
# 7) Container App Environment Module
# ----------------------------------------------------------------------------------------------------------
module "container_app_environment" {
  count  = var.deploy_infrastructure && var.deploy_container_app_environment ? 1 : 0
  source = "./modules/container_app_environment"

  container_app_environment_name     = local.container_app_environment_name
  location                           = local.resource_group_location
  resource_group_name                = local.resource_group_name
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
  container_app_env_vars = var.deploy_container_app_helloworld ? concat(
    [
      {
        name  = "AZURE_OPENAI_ENDPOINT" # Your Azure OpenAI service endpoint (e.g., https://your-service.openai.azure.com/)
        value = local.azure_openai_endpoint
      }
    ],
    local.azure_openai_env_block,
    [
      {
        name  = "AZURE_OPENAI_API_VERSION" # Azure OpenAI API version (leave as default unless you need a specific version)
        value = "2024-08-01-preview"
      },
      {
        name  = "AOAI_EMBED_MODEL" # Embedding model deployment name# Embedding model deployment name (e.g., text-embedding-3-large, text-embedding-ada-002)
        value = "text-embedding-3-large"
      },
      {
        name  = "AOAI_CHAT_MODEL" # Chat/completion model deployment name (e.g., gpt-4, gpt-35-turbo, gpt-4o-mini)
        value = "gpt-5-mini"
      },
      {
        name  = "REQUESTS_PER_MIN" # Rate limiting (requests per minute)
        value = "60"
      },
      {
        name  = "TOKENS_PER_MIN" # Token limits (tokens per minute)
        value = "60000"
      },
      {
        name  = "EST_TOKENS_PER_REQUEST" # Estimated tokens per request for rate limiting calculations
        value = "200"
      },
      # Optional:  Fine-tune how content is processed and chunked
      {
        name  = "SEMANTIC_MAX_WORDS" # Maximum words for semantic processing
        value = "300"
      },
      {
        name  = "HEADER_MAX_CHARS" # Maximum characters allowed in headers
        value = "200"
      },
      {
        name  = "HEADER_ADVANCED" # Enable advanced header processing (1 = enabled, 0 = disabled)
        value = "1"
      },
      # Header chunk processing settings
      {
        name  = "HEADER_CHUNK_HEAD"
        value = "850"
      },
      {
        name  = "HEADER_CHUNK_TAIL"
        value = "350"
      },
      {
        name  = "HEADER_NEIGHBOR_CHARS"
        value = "140"
      },
      {
        name  = "HEADER_DOC_SUMMARY_CHARS"
        value = "600"
      },
      {
        name  = "HEADER_KEYWORD_COUNT"
        value = "12"
      },
      {
        name  = "EMBED_ZERO_ON_MISSING" #Optional Dev: Set to "1" to enable zero embeddings on missing content (for testing)
        value = "0"
      },
      {
        name  = "COSMOS_DB_ENDPOINT"
        value = azurerm_cosmosdb_account.main[0].endpoint
      }
    ],
    local.cosmos_db_env_block,
    [
      {
        name  = "STORAGE_ACCOUNT_NAME"
        value = azurerm_storage_account.main[0].name
      }
    ]
  ) : []

  # Secrets for demo app
  container_app_secrets = var.deploy_container_app_helloworld ? concat(
    local.azure_openai_secret_blocks,
    local.cosmos_db_secret_blocks
  ) : []

  depends_on = [
    azurerm_resource_group.project_main_new,
    data.azurerm_resource_group.project_main_existing,
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
  source = "./modules/key_vault"

  key_vault_name                  = local.key_vault_name
  location                        = local.resource_group_location
  resource_group_name             = local.resource_group_name
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
    azurerm_resource_group.project_main_new,
    data.azurerm_resource_group.project_main_existing
  ]
}

# Data sources for existing AI Foundry account when reusing an existing project
data "azapi_resource" "existing_ai_foundry_account_default" {
  count                  = var.use_existing_ai_foundry_project && var.existing_ai_foundry_project_subscription == "" ? 1 : 0
  type                   = "Microsoft.CognitiveServices/accounts@2025-06-01"
  resource_id            = var.existing_ai_foundry_project
  provider               = azapi
  response_export_values = ["properties"]
}

data "azapi_resource" "existing_ai_foundry_account_subscription" {
  count                  = var.use_existing_ai_foundry_project && var.existing_ai_foundry_project_subscription != "" ? 1 : 0
  type                   = "Microsoft.CognitiveServices/accounts@2025-06-01"
  resource_id            = var.existing_ai_foundry_project
  provider               = azapi.existing_ai_foundry_subscription
  response_export_values = ["properties"]
}

data "azapi_resource_action" "existing_ai_foundry_account_keys_default" {
  count                  = var.use_existing_ai_foundry_project && var.existing_ai_foundry_project_subscription == "" ? 1 : 0
  type                   = "Microsoft.CognitiveServices/accounts@2025-06-01"
  resource_id            = var.existing_ai_foundry_project
  action                 = "listKeys"
  response_export_values = ["*"]
  provider               = azapi
  depends_on             = [data.azapi_resource.existing_ai_foundry_account_default]
}

data "azapi_resource_action" "existing_ai_foundry_account_keys_subscription" {
  count                  = var.use_existing_ai_foundry_project && var.existing_ai_foundry_project_subscription != "" ? 1 : 0
  type                   = "Microsoft.CognitiveServices/accounts@2025-06-01"
  resource_id            = var.existing_ai_foundry_project
  action                 = "listKeys"
  response_export_values = ["*"]
  provider               = azapi.existing_ai_foundry_subscription
  depends_on             = [data.azapi_resource.existing_ai_foundry_account_subscription]
}

# Store Azure OpenAI key in Key Vault for container app consumption
resource "azurerm_key_vault_secret" "azure_openai_api_key" {
  count        = var.deploy_infrastructure && ((var.deploy_ai_foundry_instances && !var.destroy_ai_foundry_instances) || var.use_existing_ai_foundry_project) ? 1 : 0
  name         = "azure-openai-api-key"
  value        = var.use_existing_ai_foundry_project ? local.existing_ai_foundry_account_key : module.aifoundry_1[0].ai_foundry_account_key
  key_vault_id = module.key_vault[0].key_vault_id
  depends_on   = [module.key_vault]
}

# Store Cosmos DB key in Key Vault for container app consumption
resource "azurerm_key_vault_secret" "cosmos_db_key" {
  count        = var.deploy_infrastructure ? 1 : 0
  name         = "cosmos-db-key"
  value        = azurerm_cosmosdb_account.main[0].primary_key
  key_vault_id = module.key_vault[0].key_vault_id

  depends_on = [azurerm_cosmosdb_account.main, module.key_vault]
}

locals {
  azure_openai_secret_name = "azure-openai-api-key"
  existing_ai_foundry_account_endpoint = coalesce(
    try(data.azapi_resource.existing_ai_foundry_account_default[0].output.properties.endpoint, null),
    try(data.azapi_resource.existing_ai_foundry_account_subscription[0].output.properties.endpoint, null),
    null
  )
  existing_ai_foundry_account_key = coalesce(
    try(data.azapi_resource_action.existing_ai_foundry_account_keys_default[0].output.key1, null),
    try(data.azapi_resource_action.existing_ai_foundry_account_keys_subscription[0].output.key1, null),
    null
  )
  azure_openai_endpoint = coalesce(
    try(module.aifoundry_1[0].ai_foundry_account_endpoint, null),
    local.existing_ai_foundry_account_endpoint,
    ""
  )
  azure_openai_secret_blocks_module = length(azurerm_key_vault_secret.azure_openai_api_key) > 0 ? [
    {
      name                = local.azure_openai_secret_name
      key_vault_secret_id = azurerm_key_vault_secret.azure_openai_api_key[0].versionless_id
      identity            = "System"
    }
  ] : []
  azure_openai_secret_blocks_existing = var.azure_openai_api_key_secret_id != "" ? [
    {
      name                = local.azure_openai_secret_name
      key_vault_secret_id = var.azure_openai_api_key_secret_id
      identity            = "System"
    }
  ] : []
  azure_openai_secret_blocks_inline = var.azure_openai_api_key != "" ? [
    {
      name  = local.azure_openai_secret_name
      value = var.azure_openai_api_key
    }
  ] : []
  azure_openai_secret_blocks        = length(local.azure_openai_secret_blocks_module) > 0 ? local.azure_openai_secret_blocks_module : length(local.azure_openai_secret_blocks_existing) > 0 ? local.azure_openai_secret_blocks_existing : local.azure_openai_secret_blocks_inline
  azure_openai_secret_available     = length(local.azure_openai_secret_blocks) > 0
  container_app_requires_openai_key = var.deploy_infrastructure && var.deploy_container_app_environment && var.deploy_container_app_helloworld
  cosmos_db_secret_available        = length(azurerm_key_vault_secret.cosmos_db_key) > 0

  cosmos_db_secret_blocks = local.cosmos_db_secret_available ? [
    {
      name                = "cosmos-db-key"
      key_vault_secret_id = azurerm_key_vault_secret.cosmos_db_key[0].versionless_id
      identity            = "System"
    }
  ] : []

  azure_openai_env_block = local.azure_openai_secret_available ? [
    {
      name        = "AZURE_OPENAI_API_KEY"
      secret_name = local.azure_openai_secret_name
    }
  ] : []
  cosmos_db_env_block = local.cosmos_db_secret_available ? [
    {
      name        = "COSMOS_DB_KEY"
      secret_name = "cosmos-db-key"
    }
  ] : []
}

check "azure_openai_key_supplied" {
  assert {
    condition     = !(local.container_app_requires_openai_key && !local.azure_openai_secret_available)
    error_message = "Azure OpenAI API key must be supplied via AI Foundry deployment, azure_openai_api_key_secret_id, or azure_openai_api_key when deploying the demo container app."
  }
}

# ----------------------------------------------------------------------------------------------------------
# 10) AI Foundry 1 - Primary Foundry
# ----------------------------------------------------------------------------------------------------------
module "aifoundry_1" {
  count                         = var.deploy_infrastructure && var.deploy_ai_foundry_instances && !var.destroy_ai_foundry_instances ? 1 : 0
  source                        = "./modules/ai_foundry"
  resource_group_name           = local.resource_group_name
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
      name = "gpt-5-mini"
      model = {
        format          = "OpenAI"
        name            = "gpt-5-mini"
        version         = "2025-08-07"
        rai_policy_name = "Microsoft.Default"
      }
      sku = {
        name     = "GlobalStandard"
        capacity = 150
      }
    },
    {
      name = "text-embedding-3-large"
      model = {
        format          = "OpenAI"
        name            = "text-embedding-3-large"
        version         = "1"
        rai_policy_name = "Microsoft.Default"
      }
      sku = {
        name     = "GlobalStandard"
        capacity = 150
      }
    }
  ] : []

  depends_on = [
    azurerm_resource_group.project_main_new,
    data.azurerm_resource_group.project_main_existing
  ]
}

# Terraform moved blocks to handle transition from non-count to count resources
moved {
  from = module.aifoundry_1
  to   = module.aifoundry_1[0]
}

# ----------------------------------------------------------------------------------------------------------
# 10.5) Azure AI Search Service
# ----------------------------------------------------------------------------------------------------------
module "ai_search" {
  count  = var.deploy_infrastructure && var.deploy_ai_search ? 1 : 0
  source = "./modules/ai_search"

  search_service_name           = local.ai_search_service_name
  resource_group_name           = local.resource_group_name
  location                      = local.resource_group_location
  sku_name                      = "standard"
  replica_count                 = 1
  partition_count               = 1
  public_network_access_enabled = var.deploy_private_network ? false : true
  disable_local_auth            = false
  semantic_search_sku           = "free"
  hosting_mode                  = "default"

  tags = merge(local.common_tags, {
    RGMonthlyCost = "250"
  })

  depends_on = [
    azurerm_resource_group.project_main_new,
    data.azurerm_resource_group.project_main_existing
  ]
}

# ----------------------------------------------------------------------------------------------------------
# 13) Azure Front Door
#     Azure Front Door for Container App protection. If Container App Environment is deployed, create Front Door to protect it.
# ----------------------------------------------------------------------------------------------------------
module "azure_frontdoor" {
  source = "./modules/azure_frontdoor"
  count  = var.deploy_infrastructure && var.deploy_container_app_environment && var.deploy_azure_frontdoor ? 1 : 0

  profile_name        = "${local.resource_prefix}-frontdoor"
  resource_group_name = local.resource_group_name
  sku_name            = "Standard_AzureFrontDoor"
  endpoint_name       = "${local.resource_prefix}-fd-endpoint"
  origin_host_name    = var.deploy_container_app_helloworld ? module.container_app_environment[0].container_app_fqdn : "yourapp.azurecontainerapps.io"
  #origin_host_name   = azurerm_container_app.main[0].latest_revision_fqdn
  health_probe_path = "/"
  origin_protocol   = "Https"
  tags = merge(local.common_tags, {
    RGMonthlyCost = var.deploy_private_network ? "400" : "125"
  })
  depends_on = [
    module.container_app_environment,
    azurerm_resource_group.project_main_new,
    data.azurerm_resource_group.project_main_existing
  ]
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

resource "azurerm_role_assignment" "container_app_kv_secrets_user" {
  count                = var.deploy_infrastructure && var.deploy_container_app_environment && var.deploy_container_app_helloworld ? 1 : 0
  scope                = module.key_vault[0].key_vault_id
  role_definition_name = "Key Vault Secrets User"
  principal_id         = module.container_app_environment[0].container_app_identity_principal_id
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
# AcrPull Role Assignment for Container App (app identity)
# ----------------------------------------------------------------------------------------------------------
resource "azurerm_role_assignment" "container_app_acr_pull" {
  count                = var.deploy_infrastructure && var.deploy_container_app_environment && var.deploy_container_app_helloworld ? 1 : 0
  scope                = azurerm_container_registry.main[0].id
  role_definition_name = "AcrPull"
  principal_id         = module.container_app_environment[0].container_app_identity_principal_id
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
#   resource_group_name           = azurerm_resource_group..project_main_new[0].name
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
#     azurerm_resource_group..project_main_new
#   ]
# }


# Azure Front Door Profile
# resource "azurerm_cdn_frontdoor_profile" "main" {
#   count               = var.deploy_infrastructure ? 1 : 0
#   name                = "${local.resource_prefix}-afd"
#   resource_group_name = azurerm_resource_group..project_main_new[0].name
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


