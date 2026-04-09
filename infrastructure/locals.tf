# Local values for Azure Landing Zone configuration
# Centralizes common configurations and computed values

locals {
  # Environment and naming conventions following CAF
  environment         = var.environment
  organization_prefix = var.organization_prefix
  main_location       = var.location

  # Resource naming following Azure CAF naming conventions
  resource_prefix = "${local.organization_prefix}-${local.environment}"

  # Common tags following CAF tagging strategy
  common_tags = merge(var.additional_tags, {
    Environment    = "MTCDemo"
    Industry       = "All"
    LifecycleCheck = "true"
    Partner        = "NA"
    ManagedBy      = "Terraform"
    Project        = "MedicalContextRetrieval"
  })

  # Network configuration
  #hub_vnet_name = "${local.resource_prefix}-hub-vnet"
  vnet_name = "${local.resource_prefix}-vnet"

  # Resource group names following CAF naming conventions
  rg_project_main = local.resource_prefix

  # Resource group references - use existing or new based on variables
  resource_group_name = var.deploy_infrastructure ? (
    var.use_existing_resource_group ?
    data.azurerm_resource_group.project_main_existing[0].name :
    azurerm_resource_group.project_main_new[0].name
  ) : ""

  resource_group_location = var.deploy_infrastructure ? (
    var.use_existing_resource_group ?
    data.azurerm_resource_group.project_main_existing[0].location :
    azurerm_resource_group.project_main_new[0].location
  ) : ""

  # Key Vault configuration
  key_vault_name = substr(replace("${local.resource_prefix}-kv", "-", ""), 0, 24)

  # Storage Account configuration
  storage_account_name = lower(replace("${local.resource_prefix}sa", "-", ""))

  # Cosmos DB configuration
  cosmos_db_name = lower("${local.resource_prefix}-cosmos")
  #cosmos_db_database_name = "zava-db"
  # cosmos_db_database_id = "sustineo"
  # cosmos_db_container_id     = "VoiceConfiguration"
  # cosmos_db_container_partition_key = "/id"

  # Active database name — resolves to whichever resource is active based on cosmos_db_force_recreate
  cosmos_db_active_database_name = var.deploy_infrastructure ? (
    var.cosmos_db_force_recreate
    ? try(azurerm_cosmosdb_sql_database.recreatable[0].name, "")
    : try(azurerm_cosmosdb_sql_database.default[0].name, "")
  ) : ""

  # Container App configuration
  container_app_environment_name = lower("${local.resource_prefix}-cae")
  container_app_name             = lower("${local.resource_prefix}-ca")

  application_insights_name = "${local.resource_prefix}-appi"
  container_registry_name   = lower(replace("${local.resource_prefix}acr", "-", ""))

  # AI Search configuration
  ai_search_service_name = lower("${local.resource_prefix}-search")

  #AI Foundry config
  aifoundry_account1_name = "${local.resource_prefix}-aif1-${var.aif_location1}"

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

  # Azure OpenAI and secret configuration
  azure_openai_secret_name = "azure-openai-api-key"
  existing_ai_foundry_account_endpoint = coalesce(
    try(data.azapi_resource.existing_ai_foundry_account_default[0].output.properties.endpoint, null),
    try(data.azapi_resource.existing_ai_foundry_account_subscription[0].output.properties.endpoint, null),
    null
  )
  existing_ai_foundry_account_key = var.existing_ai_foundry_local_auth_disabled ? null : coalesce(
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
  # TODO: Migrate to RBAC with managed identity (Cosmos DB Built-in Data Contributor role) to eliminate key-based auth
  cosmos_db_env_block = local.cosmos_db_secret_available ? [
    {
      name        = "COSMOS_KEY"
      secret_name = "cosmos-db-key"
    }
  ] : []
}
