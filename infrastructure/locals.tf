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
  vnet_name     = "${local.resource_prefix}-vnet"

  # Resource group names following CAF naming conventions
  rg_project_main         = local.resource_prefix

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
  cosmos_db_name          = lower("${local.resource_prefix}-cosmos")
  #cosmos_db_database_name = "zava-db"
  # cosmos_db_database_id = "sustineo"
  # cosmos_db_container_id     = "VoiceConfiguration"
  # cosmos_db_container_partition_key = "/id"

  # Container App configuration
  container_app_environment_name = lower("${local.resource_prefix}-cae")
  container_app_name             = lower("${local.resource_prefix}-ca")

  application_insights_name = "${local.resource_prefix}-appi"
  container_registry_name   = lower(replace("${local.resource_prefix}acr", "-", ""))

  # AI Search configuration
  ai_search_service_name = lower("${local.resource_prefix}-search")

  #AI Foundry config
  aifoundry_account1_name = "${local.resource_prefix}-aif1-${var.aif_location1}"
}
