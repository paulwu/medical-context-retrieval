output "id" {
  value       = azurerm_private_endpoint.this.id
  description = "ID of the private endpoint"
}

output "network_interface_ids" {
  value       = azurerm_private_endpoint.this.network_interface
  description = "List of network interface objects associated with the private endpoint"
}
