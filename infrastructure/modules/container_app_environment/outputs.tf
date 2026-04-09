# Outputs for Container App Environment Module

output "container_app_environment_id" {
  description = "ID of the Container App Environment"
  value       = azapi_resource.container_app_environment.id
}

output "container_app_environment_name" {
  description = "Name of the Container App Environment"
  value       = azapi_resource.container_app_environment.name
}

output "container_app_environment_default_domain" {
  description = "Default domain of the Container App Environment"
  value       = try(jsondecode(azapi_resource.container_app_environment.output).properties.defaultDomain, null)
}

output "container_app_environment_static_ip_address" {
  description = "Static IP address of the Container App Environment"
  value       = try(jsondecode(azapi_resource.container_app_environment.output).properties.staticIp, null)
}

# Container App Environment Managed Identity outputs
output "container_app_environment_identity_principal_id" {
  description = "Principal ID of the Container App Environment's managed identity"
  value       = azapi_resource.container_app_environment.identity[0].principal_id
}

output "container_app_environment_identity_tenant_id" {
  description = "Tenant ID of the Container App Environment's managed identity"
  value       = azapi_resource.container_app_environment.identity[0].tenant_id
}

# Container App Outputs (always available — app is created with the environment)
output "container_app_id" {
  description = "ID of the Container App"
  value       = azurerm_container_app.helloworld[0].id
}

output "container_app_name" {
  description = "Name of the Container App"
  value       = azurerm_container_app.helloworld[0].name
}

output "container_app_fqdn" {
  description = "FQDN of the Container App"
  value       = var.enable_ingress ? azurerm_container_app.helloworld[0].ingress[0].fqdn : null
}

output "container_app_url" {
  description = "URL of the Container App"
  value       = var.enable_ingress ? "https://${azurerm_container_app.helloworld[0].ingress[0].fqdn}" : null
}

output "container_app_latest_revision_name" {
  description = "Latest revision name of the Container App"
  value       = azurerm_container_app.helloworld[0].latest_revision_name
}

output "container_app_latest_revision_fqdn" {
  description = "Latest revision FQDN of the Container App"
  value       = azurerm_container_app.helloworld[0].latest_revision_fqdn
}

output "container_app_identity_principal_id" {
  description = "Principal ID of the Container App's managed identity"
  value       = azurerm_container_app.helloworld[0].identity[0].principal_id
}

output "container_app_identity_tenant_id" {
  description = "Tenant ID of the Container App's managed identity"
  value       = azurerm_container_app.helloworld[0].identity[0].tenant_id
}
