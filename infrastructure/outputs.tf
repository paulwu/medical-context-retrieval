# Outputs for Azure Landing Zone Terraform Configuration
# Following Azure Cloud Adoption Framework (CAF) best practices

# Resource Group Outputs
output "zava_demo_resource_group_name" {
  description = "Name of the zava demo resource group"
  value       = var.deploy_infrastructure ? azurerm_resource_group.zava_demo[0].name : null
}

output "zava_demo_resource_group_id" {
  description = "ID of the zava demo resource group"
  value       = var.deploy_infrastructure ? azurerm_resource_group.zava_demo[0].id : null
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

# AI Model Deployment Outputs
# output "gpt4o_mini_realtime_deployment_id" { # UNUSED
#   description = "ID of the GPT-4o-mini-realtime-preview model deployment" # UNUSED
#   value       = var.deploy_infrastructure && var.deploy_gpt4o_mini_realtime ? azurerm_cognitive_deployment.gpt4o_mini_realtime[0].id : null # UNUSED
# }

# output "gpt_image_deployment_id" {
#   description = "ID of the GPT-Image-1 model deployment"
#   value       = var.deploy_infrastructure && var.deploy_gpt_image_model ? azurerm_cognitive_deployment.gpt-image-1[0].id : null
# }

# output "sora_deployment_id" {
#   description = "ID of the Sora model deployment"
#   value       = var.deploy_infrastructure && var.deploy_sora_model ? azurerm_cognitive_deployment.sora[0].id : null
# }

# AI Hub and Project Outputs
# output "ai_hub_id" {
#   description = "ID of the Azure AI Hub"
#   value       = var.deploy_infrastructure ? azurerm_machine_learning_workspace.ai_hub[0].id : null
# }

# output "ai_hub_name" {
#   description = "Name of the Azure AI Hub"
#   value       = var.deploy_infrastructure ? azurerm_machine_learning_workspace.ai_hub[0].name : null
# }

# output "ai_project_id" {
#   description = "ID of the Azure AI Project"
#   value       = var.deploy_infrastructure ? azurerm_machine_learning_workspace.ai_project[0].id : null
# }

# output "ai_project_name" {
#   description = "Name of the Azure AI Project"
#   value       = var.deploy_infrastructure ? azurerm_machine_learning_workspace.ai_project[0].name : null
# }

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
    gpt4o_mini_realtime_deployed = var.deploy_infrastructure && var.deploy_gpt4o_mini_realtime
    dalle3_deployed              = var.deploy_infrastructure && var.deploy_gpt_image_model
    sora_deployed                = var.deploy_infrastructure && var.deploy_sora_model
    ai_foundry_endpoint          = var.deploy_infrastructure && var.deploy_ai_foundry_instances ? module.aifoundry_1[0].ai_foundry_account_endpoint : null
    ai_foundry_project_name      = "aifoundry-project-dev"
    ai_foundry_hub_name          = "aifoundry-hub-dev"
  }
}

# Azure Front Door Outputs
output "azure_frontdoor_id" {
  description = "ID of the Azure Front Door profile"
  value       = var.deploy_infrastructure && var.deploy_container_app_environment ? module.azure_frontdoor[0].profile_id : null
}

output "azure_frontdoor_endpoint_hostname" {
  description = "Hostname of the Azure Front Door endpoint"
  value       = var.deploy_infrastructure && var.deploy_container_app_environment ? module.azure_frontdoor[0].endpoint_host : null
}

output "azure_frontdoor_endpoint_url" {
  description = "Full URL of the Azure Front Door endpoint"
  value       = var.deploy_infrastructure && var.deploy_container_app_environment ? "https://${module.azure_frontdoor[0].endpoint_host}" : null
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
