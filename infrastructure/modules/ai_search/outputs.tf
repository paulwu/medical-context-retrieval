# AI Search Module - Outputs

output "search_service_id" {
  description = "ID of the AI Search service"
  value       = azurerm_search_service.main.id
}

output "search_service_name" {
  description = "Name of the AI Search service"
  value       = azurerm_search_service.main.name
}

output "search_service_url" {
  description = "URL of the AI Search service"
  value       = "https://${azurerm_search_service.main.name}.search.windows.net"
}

output "search_service_endpoint" {
  description = "Endpoint of the AI Search service"
  value       = azurerm_search_service.main.name
}

output "search_service_primary_key" {
  description = "Primary admin key for the AI Search service"
  value       = azurerm_search_service.main.primary_key
  sensitive   = true
}

output "search_service_secondary_key" {
  description = "Secondary admin key for the AI Search service"
  value       = azurerm_search_service.main.secondary_key
  sensitive   = true
}

output "search_service_query_keys" {
  description = "Query keys for the AI Search service"
  value       = azurerm_search_service.main.query_keys
  sensitive   = true
}

output "search_service_resource_group_name" {
  description = "Resource group name of the AI Search service"
  value       = azurerm_search_service.main.resource_group_name
}

output "search_service_location" {
  description = "Location of the AI Search service"
  value       = azurerm_search_service.main.location
}

output "search_service_sku" {
  description = "SKU of the AI Search service"
  value       = azurerm_search_service.main.sku
}

output "search_service_replica_count" {
  description = "Number of replicas for the AI Search service"
  value       = azurerm_search_service.main.replica_count
}

output "search_service_partition_count" {
  description = "Number of partitions for the AI Search service"
  value       = azurerm_search_service.main.partition_count
}