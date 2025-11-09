output "vnet_id" {
  value       = azurerm_virtual_network.this.id
  description = "ID of the created virtual network"
}

output "subnet_ids" {
  value       = { for k, s in azurerm_subnet.this : k => s.id }
  description = "Map of subnet keys to subnet IDs"
}
