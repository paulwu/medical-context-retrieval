# Outputs for the private_network module

# VNet outputs
output "vnet_id" {
  value       = module.vnet.vnet_id
  description = "ID of the created virtual network"
}

output "subnet_ids" {
  value       = module.vnet.subnet_ids
  description = "Map of subnet keys to subnet IDs"
}

# Private DNS Zone outputs
output "private_dns_zone_ids" {
  value       = { for zone_name, zone_module in module.private_dns_zones : zone_name => zone_module.zone_id }
  description = "Map of DNS zone names to zone IDs"
}

output "private_dns_zone_names" {
  value       = { for zone_name, zone_module in module.private_dns_zones : zone_name => zone_module.name }
  description = "Map of DNS zone names to zone names (for reference)"
}

# Private Endpoint outputs
output "private_endpoint_ids" {
  value       = { for pe_key, pe_module in module.private_endpoints : pe_key => pe_module.id }
  description = "Map of private endpoint keys to endpoint IDs"
}

output "private_endpoint_network_interfaces" {
  value       = { for pe_key, pe_module in module.private_endpoints : pe_key => pe_module.network_interface_ids }
  description = "Map of private endpoint keys to network interface objects"
}
