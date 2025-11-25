# Private Network Module - Orchestrates VNet, Private Endpoints, and Private DNS Zones

# ----------------------------------------------------------------------------------------------------------
# Virtual Network and Subnets
# ----------------------------------------------------------------------------------------------------------
module "vnet" {
  source = "../vnet"
  
  vnet_name           = var.vnet_name
  location            = var.location
  resource_group_name = var.resource_group_name
  address_space       = var.vnet_address_space
  subnets             = var.subnets
  tags                = var.tags
}

# ----------------------------------------------------------------------------------------------------------
# Private DNS Zones (create unique zones based on private endpoints configuration)
# ----------------------------------------------------------------------------------------------------------
locals {
  # Extract unique DNS zone names from private endpoints configuration
  dns_zones = toset([
    for pe_key, pe_config in var.private_endpoints : pe_config.private_dns_zone_name
  ])
}

module "private_dns_zones" {
  for_each = local.dns_zones
  source   = "../private_dns_zone"
  
  zone_name           = each.value
  resource_group_name = var.resource_group_name
  
  virtual_network_ids = {
    main = module.vnet.vnet_id
  }
  
  tags = var.tags
  
  depends_on = [module.vnet]
}

# ----------------------------------------------------------------------------------------------------------
# Private Endpoints
# ----------------------------------------------------------------------------------------------------------
module "private_endpoints" {
  for_each = var.private_endpoints
  source   = "../private_endpoint"
  
  name                           = each.value.name
  location                       = var.location
  resource_group_name            = var.resource_group_name
  subnet_id                      = module.vnet.subnet_ids["private_endpoints"]
  private_connection_resource_id = each.value.private_connection_resource_id
  subresource_names              = each.value.subresource_names
  private_dns_zone_ids           = [module.private_dns_zones[each.value.private_dns_zone_name].zone_id]
  
  tags = var.tags
  
  depends_on = [
    module.vnet,
    module.private_dns_zones
  ]
}
