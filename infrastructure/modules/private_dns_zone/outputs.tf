output "zone_id" {
  value       = azurerm_private_dns_zone.this.id
  description = "ID of the private DNS zone"
}

output "name" {
  value       = azurerm_private_dns_zone.this.name
  description = "Name of the private DNS zone"
}
