# Private DNS Zone Module

Creates an Azure Private DNS Zone and links it to one or more virtual networks.

## Resources Created

- azurerm_private_dns_zone
- azurerm_private_dns_zone_virtual_network_link (per VNet entry)

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| zone_name | string | yes | DNS zone name (e.g. privatelink.vaultcore.azure.net) |
| resource_group_name | string | yes | Resource group name |
| virtual_network_ids | map(string) | no | Map of key=>VNet ID to link (no auto-registration) |
| tags | map(string) | no | Tags applied to resources |

## Outputs

| Name | Description |
|------|-------------|
| zone_id | Private DNS zone resource ID |
| name | DNS zone name |

## Example

```hcl
module "kv_private_dns" {
  source              = "./Modules/private_dns_zone"
  zone_name           = "privatelink.vaultcore.azure.net"
  resource_group_name = azurerm_resource_group.zava_demo[0].name
  virtual_network_ids = { primary = module.network.vnet_id }
}
```

## Notes

- Use appropriate zone names per service (e.g. privatelink.blob.core.windows.net, privatelink.documents.azure.com, privatelink.azurecontainerapps.io).
- For auto-registration (not typical for PaaS private endpoints), you would toggle registration_enabled, which is currently false.
