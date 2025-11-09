# Azure Front Door Module (Front Door Standard/Premium)

Provision an Azure Front Door (Standard/Premium) profile with a single endpoint, origin group, origin, and route forwarding all paths to a supplied origin host (e.g. Azure Container Apps default hostname).

## Resources Created

- azurerm_cdn_frontdoor_profile
- azurerm_cdn_frontdoor_origin_group
- azurerm_cdn_frontdoor_endpoint
- azurerm_cdn_frontdoor_origin
- azurerm_cdn_frontdoor_route

## Inputs

| Name | Type | Required | Description |
|------|------|----------|-------------|
| profile_name | string | yes | Front Door profile name |
| resource_group_name | string | yes | Resource group name |
| sku_name | string | no (default Standard_AzureFrontDoor) | SKU (Standard_AzureFrontDoor or Premium_AzureFrontDoor) |
| endpoint_name | string | yes | Endpoint name |
| origin_host_name | string | yes | FQDN of origin (container app hostname, web app, etc.) |
| origin_host_header | string | no | Override host header sent to origin |
| health_probe_path | string | no ("/") | Path for health probe |
| origin_protocol | string | no ("Https") | Health probe protocol |
| tags | map(string) | no | Tags applied to all resources |

## Outputs

| Name | Description |
|------|-------------|
| profile_id | Front Door profile resource ID |
| endpoint_id | Endpoint resource ID |
| endpoint_host | Public hostname of endpoint |

## Example

```hcl
module "frontdoor" {
  source              = "./Modules/azure_frontdoor"
  profile_name        = "fd-ai-demo"
  resource_group_name = azurerm_resource_group.zava_demo[0].name
  endpoint_name       = "fd-ai-demo-endpoint"
  origin_host_name    = azurerm_container_app.main[0].ingress[0].fqdn
  tags = {
    Environment = var.environment
  }
}
```

## Notes

- Add WAF policies, rule sets, custom domains, and security policies by extending this module later.
- Private origin access for Container Apps requires an internal endpoint + private DNS; ensure origin hostname is reachable from Front Door (public today—private preview features evolving).
