# Virtual Network Module

Creates an Azure Virtual Network and a flexible set of subnets.

## Resources Created

- azurerm_virtual_network
- azurerm_subnet (for each entry in `subnets`)

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| vnet_name | string | yes | Virtual network name |
| location | string | yes | Azure region |
| resource_group_name | string | yes | Resource group name |
| address_space | list(string) | yes | VNet address space CIDRs |
| dns_servers | list(string) | no | Custom DNS servers |
| subnets | map(object) | no | Map of subnet definitions (name, address_prefixes, optional service_endpoints, delegations placeholder) |
| tags | map(string) | no | Tags applied to resources |

## Outputs

| Name | Description |
|------|-------------|
| vnet_id | VNet resource ID |
| subnet_ids | Map of defined subnet keys to their IDs |

## Example

```hcl
module "network" {
  source              = "./Modules/vnet"
  vnet_name           = "zava-vnet"
  location            = local.location
  resource_group_name = azurerm_resource_group.zava_demo[0].name
  address_space       = ["10.50.0.0/16"]
  subnets = {
    app = {
      name             = "app-subnet"
      address_prefixes = ["10.50.1.0/24"]
    }
    pe = {
      name             = "private-endpoints"
      address_prefixes = ["10.50.10.0/24"]
    }
  }
}
```

## Notes

- Add subnet delegation or NSG association outside or extend module as needed.
- Maintain consistent CIDR strategy across environments.
