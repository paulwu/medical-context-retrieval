# Outputs for Azure Landing Zone Terraform Configuration
# Following Azure Cloud Adoption Framework (CAF) best practices

# Resource Group Outputs
output "medical_ctx_rag_resource_group_name" {
  description = "Name of the medical_ctx_rag resource group"
  value       = var.deploy_infrastructure ? local.resource_group_name : null
}

output "medical_ctx_rag_resource_group_id" {
  description = "ID of the medical_ctx_rag resource group"
  value       = var.deploy_infrastructure ? (
    var.use_existing_resource_group ? 
    data.azurerm_resource_group.project_main_existing[0].id : 
    azurerm_resource_group.project_main_new[0].id
  ) : null
}

# Log Analytics Workspace Outputs
# output "log_analytics_workspace_id" {
#   description = "ID of the Log Analytics Workspace"
#   value       = var.deploy_infrastructure ? azurerm_log_analytics_workspace.main[0].id : null
# }

# output "log_analytics_workspace_name" {
#   description = "Name of the Log Analytics Workspace"
#   value       = var.deploy_infrastructure ? azurerm_log_analytics_workspace.main[0].name : null
# }

# Storage Account Outputs
output "storage_account_id" {
  description = "ID of the Storage Account"
  value       = var.deploy_infrastructure ? azurerm_storage_account.main[0].id : null
}

output "storage_account_name" {
  description = "Name of the Storage Account"
  value       = var.deploy_infrastructure ? azurerm_storage_account.main[0].name : null
}

output "storage_account_primary_endpoint" {
  description = "Primary blob endpoint of the Storage Account"
  value       = var.deploy_infrastructure ? azurerm_storage_account.main[0].primary_blob_endpoint : null
}

# Cosmos DB Outputs
output "cosmos_db_id" {
  description = "ID of the Cosmos DB Account"
  value       = var.deploy_infrastructure ? azurerm_cosmosdb_account.main[0].id : null
}

output "cosmos_db_endpoint" {
  description = "Endpoint of the Cosmos DB Account"
  value       = var.deploy_infrastructure ? azurerm_cosmosdb_account.main[0].endpoint : null
}

# Container App Outputs
output "container_app_id" {
  description = "ID of the Container App"
  value       = var.deploy_infrastructure && var.deploy_container_app_environment && var.deploy_container_app_helloworld ? module.container_app_environment[0].container_app_id : null
}

output "container_app_name" {
  description = "Name of the Container App"
  value       = var.deploy_infrastructure && var.deploy_container_app_environment && var.deploy_container_app_helloworld ? module.container_app_environment[0].container_app_name : null
}

output "container_app_url" {
  description = "URL of the Container App"
  value       = var.deploy_infrastructure && var.deploy_container_app_environment && var.deploy_container_app_helloworld ? module.container_app_environment[0].container_app_url : null
}

output "container_app_environment_id" {
  description = "ID of the Container App Environment"
  value       = var.deploy_infrastructure && var.deploy_container_app_environment ? module.container_app_environment[0].container_app_environment_id : null
}

output "container_app_environment_identity_principal_id" {
  description = "Principal ID of the Container App Environment's managed identity"
  value       = var.deploy_infrastructure && var.deploy_container_app_environment ? module.container_app_environment[0].container_app_environment_identity_principal_id : null
}

output "container_app_environment_identity_tenant_id" {
  description = "Tenant ID of the Container App Environment's managed identity"
  value       = var.deploy_infrastructure && var.deploy_container_app_environment ? module.container_app_environment[0].container_app_environment_identity_tenant_id : null
}

output "container_app_identity_principal_id" {
  description = "Principal ID of the Container App's managed identity"
  value       = var.deploy_infrastructure && var.deploy_container_app_environment && var.deploy_container_app_helloworld ? module.container_app_environment[0].container_app_identity_principal_id : null
}

output "container_app_identity_tenant_id" {
  description = "Tenant ID of the Container App's managed identity"
  value       = var.deploy_infrastructure && var.deploy_container_app_environment && var.deploy_container_app_helloworld ? module.container_app_environment[0].container_app_identity_tenant_id : null
}

# AI Foundry Outputs
output "ai_foundry_account_id" {
  description = "ID of the AI Foundry Account (primary)"
  value       = var.deploy_infrastructure && var.deploy_ai_foundry_instances ? module.aifoundry_1[0].ai_foundry_account_id : null
}

output "ai_foundry_account_name" {
  description = "Name of the AI Foundry Account (primary)"
  value       = var.deploy_infrastructure && var.deploy_ai_foundry_instances ? module.aifoundry_1[0].ai_foundry_account_name : null
}

output "ai_foundry_endpoint" {
  description = "Endpoint of the AI Foundry service (primary)"
  value       = var.deploy_infrastructure && var.deploy_ai_foundry_instances ? module.aifoundry_1[0].ai_foundry_account_endpoint : null
}

# Supporting Services Outputs
output "application_insights_id" {
  description = "ID of the Application Insights"
  value       = var.deploy_infrastructure ? azurerm_application_insights.main[0].id : null
}

# Additional Application Insights Outputs
output "application_insights_name" {
  description = "Name of the Application Insights resource"
  value       = var.deploy_infrastructure ? azurerm_application_insights.main[0].name : null
}

output "application_insights_app_id" {
  description = "App ID of the Application Insights resource"
  value       = var.deploy_infrastructure ? azurerm_application_insights.main[0].app_id : null
}

output "application_insights_instrumentation_key" {
  description = "Instrumentation Key for Application Insights (legacy)"
  value       = var.deploy_infrastructure ? azurerm_application_insights.main[0].instrumentation_key : null
  sensitive   = true
}

output "application_insights_connection_string" {
  description = "Connection string for Application Insights"
  value       = var.deploy_infrastructure ? azurerm_application_insights.main[0].connection_string : null
  sensitive   = true
}

output "application_insights_workspace_id" {
  description = "Linked Log Analytics Workspace ID (if any)"
  value       = var.deploy_infrastructure ? azurerm_application_insights.main[0].workspace_id : null
}

output "key_vault_id" {
  description = "ID of the Key Vault"
  value       = var.deploy_infrastructure ? module.key_vault[0].key_vault_id : null
}

output "key_vault_uri" {
  description = "URI of the Key Vault"
  value       = var.deploy_infrastructure ? module.key_vault[0].key_vault_uri : null
  sensitive   = true
}

output "container_registry_id" {
  description = "ID of the Container Registry"
  value       = var.deploy_infrastructure ? azurerm_container_registry.main[0].id : null
}

output "container_registry_login_server" {
  description = "Login server URL for the Container Registry"
  value       = var.deploy_infrastructure ? azurerm_container_registry.main[0].login_server : null
}

# Summary Information
output "deployment_summary" {
  description = "Summary of deployed components"
  value = {
    environment             = var.environment
    organization_prefix     = var.organization_prefix
    location                = var.location
    resource_group_deployed = var.deploy_infrastructure
    ai_services_deployed    = var.deploy_infrastructure
    ai_foundry_deployed     = var.deploy_infrastructure && var.deploy_ai_foundry_instances
    deployment_timestamp    = timestamp()
  }
}

# AI Models Summary
output "ai_models_summary" {
  description = "Summary of deployed AI models"
  value = {
    ai_model_deployments_enabled = var.deploy_infrastructure && var.deploy_ai_model_deployments
    ai_foundry_endpoint          = var.deploy_infrastructure && var.deploy_ai_foundry_instances ? module.aifoundry_1[0].ai_foundry_account_endpoint : null
    ai_foundry_project_name      = "aifoundry-project-dev"
    ai_foundry_hub_name          = "aifoundry-hub-dev"
  }
}

# Azure Front Door Outputs
output "azure_frontdoor_id" {
  description = "ID of the Azure Front Door profile"
  value       = var.deploy_infrastructure && var.deploy_container_app_environment && var.deploy_azure_frontdoor ? module.azure_frontdoor[0].profile_id : null
}

output "azure_frontdoor_endpoint_hostname" {
  description = "Hostname of the Azure Front Door endpoint"
  value       = var.deploy_infrastructure && var.deploy_container_app_environment && var.deploy_azure_frontdoor ? module.azure_frontdoor[0].endpoint_host : null
}

output "azure_frontdoor_endpoint_url" {
  description = "Full URL of the Azure Front Door endpoint"
  value       = var.deploy_infrastructure && var.deploy_container_app_environment && var.deploy_azure_frontdoor ? "https://${module.azure_frontdoor[0].endpoint_host}" : null
}

# Network Outputs
output "vnet_id" {
  description = "ID of the virtual network"
  value       = var.deploy_infrastructure && var.deploy_private_network ? module.private_network[0].vnet_id : null
}

output "subnet_ids" {
  description = "Map of subnet names to IDs"
  value       = var.deploy_infrastructure && var.deploy_private_network ? module.private_network[0].subnet_ids : null
}

# Private Endpoint Outputs
output "storage_private_endpoint_id" {
  description = "ID of the Storage Account private endpoint"
  value       = var.deploy_infrastructure && var.deploy_private_network ? module.private_network[0].private_endpoint_ids["storage"] : null
}

output "keyvault_private_endpoint_id" {
  description = "ID of the Key Vault private endpoint"
  value       = var.deploy_infrastructure && var.deploy_private_network ? module.private_network[0].private_endpoint_ids["keyvault"] : null
}

output "cosmosdb_private_endpoint_id" {
  description = "ID of the Cosmos DB private endpoint"
  value       = var.deploy_infrastructure && var.deploy_private_network ? module.private_network[0].private_endpoint_ids["cosmosdb"] : null
}

output "aifoundry_private_endpoint1_id" {
  description = "ID of the AI Foundry private endpoint"
  value       = var.deploy_infrastructure && var.deploy_private_network ? module.private_network[0].private_endpoint_ids["aifoundry1"] : null
}

# Private DNS Zone Outputs
output "private_dns_zone_ids" {
  description = "Map of DNS zone names to zone IDs"
  value       = var.deploy_infrastructure && var.deploy_private_network ? module.private_network[0].private_dns_zone_ids : null
}

output "container_app_fqdn" {
  description = "FQDN of the Container App (origin)"
  value       = var.deploy_infrastructure && var.deploy_container_app_environment && var.deploy_container_app_helloworld ? module.container_app_environment[0].container_app_fqdn : null
}

# Azure AI Search Outputs
output "ai_search_service_id" {
  description = "ID of the AI Search service"
  value       = var.deploy_infrastructure && var.deploy_ai_search ? module.ai_search[0].search_service_id : null
}

output "ai_search_service_name" {
  description = "Name of the AI Search service"
  value       = var.deploy_infrastructure && var.deploy_ai_search ? module.ai_search[0].search_service_name : null
}

output "ai_search_service_url" {
  description = "URL of the AI Search service"
  value       = var.deploy_infrastructure && var.deploy_ai_search ? module.ai_search[0].search_service_url : null
}

output "ai_search_service_endpoint" {
  description = "Endpoint of the AI Search service"
  value       = var.deploy_infrastructure && var.deploy_ai_search ? module.ai_search[0].search_service_endpoint : null
}

output "ai_search_service_primary_key" {
  description = "Primary admin key for the AI Search service"
  value       = var.deploy_infrastructure && var.deploy_ai_search ? module.ai_search[0].search_service_primary_key : null
  sensitive   = true
}
