# Private Endpoint Module

Creates an Azure Private Endpoint to a target resource (Storage, Key Vault, Cosmos DB, etc.) with optional Private DNS zone group association.

## Resources Created

- azurerm_private_endpoint

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| name | string | yes | Private Endpoint name |
| location | string | yes | Azure region |
| resource_group_name | string | yes | Resource group name |
| subnet_id | string | yes | Subnet ID for placement (should be dedicated for endpoints) |
| private_connection_resource_id | string | yes | Target resource ID |
| subresource_names | list(string) | no | Subresources (e.g. ["blob"], ["vault"], ["sql"], ["account"] depending on service) |
| request_message | string | no | Optional request message (manual approval scenarios) |
| private_dns_zone_ids | list(string) | no | Private DNS zone IDs to auto-link (creates zone group) |
| tags | map(string) | no | Tags applied to the private endpoint |

## Outputs

| Name | Description |
|------|-------------|
| id | Private Endpoint resource ID |
| network_interface_ids | NIC IDs for the PE (for diagnostics) |

## Example

```hcl
module "pe_kv" {
  source                        = "./Modules/private_endpoint"
  name                          = "pe-keyvault"
  location                      = local.location
  resource_group_name           = azurerm_resource_group.zava_demo[0].name
  subnet_id                     = module.network.subnet_ids["pe"]
  private_connection_resource_id = azurerm_key_vault.main[0].id
  subresource_names             = ["vault"]
  private_dns_zone_ids          = [module.kv_private_dns.zone_id]
}
```

## Notes

- Each service exposes specific subresource names; consult the Azure provider docs for the resource type.
- Recommended: isolate private endpoints in a dedicated subnet with a Network Security Group.
