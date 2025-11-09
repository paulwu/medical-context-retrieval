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
    Project        = "Zava"
  })

  # Network configuration
  #hub_vnet_name = "${local.resource_prefix}-hub-vnet"
  vnet_name     = "${local.resource_prefix}-vnet"

  # Resource group names following CAF naming conventions
  rg_zava_demo         = local.resource_prefix

  # Key Vault configuration
  key_vault_name = substr(replace("${local.resource_prefix}-kv", "-", ""), 0, 24)

  # Log Analytics Workspace configuration
  log_analytics_name = "${local.resource_prefix}-law"

  # Automation Account configuration
  automation_account_name = "${local.resource_prefix}-aa"

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

  # AI Hub and Project configuration
  ai_hub_name               = "${local.resource_prefix}-ai-hub"
  ai_project_name           = "${local.resource_prefix}-ai-project"
  application_insights_name = "${local.resource_prefix}-appi"
  container_registry_name   = lower(replace("${local.resource_prefix}acr", "-", ""))

  #AI Foundry config
  aifoundry_account1_name = "${local.resource_prefix}-aif1-${var.aif_location1}"
  aifoundry_account2_name = "${local.resource_prefix}-aif2-${var.aif_location2}"

  # Cognitive Services configuration
  cognitive_services_name      = "${local.resource_prefix}-cognitive"
  cognitive_services_subdomain = lower("${local.resource_prefix}-cognitive")

  # Network security configuration
  default_corp_nsg_rules = [
    {
      name                       = "AllowHTTPS"
      priority                   = 1001
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "VirtualNetwork"
      destination_address_prefix = "*"
    },
    {
      name                       = "AllowRDP"
      priority                   = 1002
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "3389"
      source_address_prefix      = "10.0.0.0/8"
      destination_address_prefix = "*"
    },
    {
      name                       = "AllowSSH"
      priority                   = 1003
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "22"
      source_address_prefix      = "10.0.0.0/8"
      destination_address_prefix = "*"
    }
  ]

  default_online_nsg_rules = [
    {
      name                       = "AllowHTTP"
      priority                   = 1001
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "80"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    },
    {
      name                       = "AllowHTTPS"
      priority                   = 1002
      direction                  = "Inbound"
      access                     = "Allow"
      protocol                   = "Tcp"
      source_port_range          = "*"
      destination_port_range     = "443"
      source_address_prefix      = "*"
      destination_address_prefix = "*"
    }
  ]
}
