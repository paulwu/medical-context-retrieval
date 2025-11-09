output "profile_id" {
  value       = azurerm_cdn_frontdoor_profile.this.id
  description = "ID of the Front Door (Front Door Standard/Premium) profile"
}

output "endpoint_id" {
  value       = azurerm_cdn_frontdoor_endpoint.this.id
  description = "ID of the Front Door endpoint"
}

output "endpoint_host" {
  value       = azurerm_cdn_frontdoor_endpoint.this.host_name
  description = "Host name of the Front Door endpoint"
}
