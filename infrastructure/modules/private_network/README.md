# Private Network Module

This module orchestrates the creation of a complete private networking setup including:
- Virtual Network with dedicated subnets for Container Apps and private endpoints
- Private DNS Zones for comprehensive service resolution
- Private Endpoints for secure connectivity to all Azure services
- Container Apps Environment integration with internal load balancer

## Features

- **🌐 VNet Integration**: Creates a VNet with configurable subnets including Container Apps infrastructure subnet (10.240.0.0/23) and private endpoints subnet (10.240.2.0/24)
- **🔒 Complete Private DNS**: Automatically creates private DNS zones based on the private endpoints configuration (7+ zones supported)
- **🔗 Comprehensive Private Endpoints**: Creates private endpoints for various Azure services with automatic DNS integration
- **📦 Container Apps Integration**: Configures Container Apps Environment with internal load balancer for private-only access
- **🏗️ Modular Design**: Reuses existing vnet, private_endpoint, and private_dns_zone modules

## Supported Private Endpoints

The module supports private endpoints for all major Azure services:

| Service | Private DNS Zone | Subresource | Purpose |
|---------|------------------|-------------|---------|
| **Storage Account** | `privatelink.blob.core.windows.net` | `blob` | Secure blob storage access |
| **Key Vault** | `privatelink.vaultcore.azure.net` | `vault` | Secure secrets management |
| **Cosmos DB** | `privatelink.documents.azure.com` | `sql` | Private database connectivity |
| **AI Services** | `privatelink.cognitiveservices.azure.com` | `account` | AI/OpenAI service access |
| **Container Registry** | `privatelink.azurecr.io` | `registry` | Private container image pulls |
| **Container Apps Environment** | `privatelink.azurecontainerapps.io` | `managedEnvironments` | Internal app access |
| **Azure Front Door** | `privatelink.azurefd.net` | `azureFrontDoor` | Private CDN connectivity |

## Architecture

```text
Virtual Network (10.240.0.0/16)
├── Container Apps Infrastructure Subnet (10.240.0.0/23)
│   ├── Container Apps Environment (internal load balancer)
│   └── Container Apps (private-only access)
└── Private Endpoints Subnet (10.240.2.0/24)
    ├── Storage Account Private Endpoint
    ├── Key Vault Private Endpoint
    ├── Cosmos DB Private Endpoint
    ├── AI Services Private Endpoint
    ├── Container Registry Private Endpoint
    ├── Container Apps Environment Private Endpoint
    └── Azure Front Door Private Endpoint

Private DNS Zones (automatic VNet linking)
├── privatelink.blob.core.windows.net
├── privatelink.vaultcore.azure.net
├── privatelink.documents.azure.com
├── privatelink.cognitiveservices.azure.com
├── privatelink.azurecr.io
├── privatelink.azurecontainerapps.io
└── privatelink.azurefd.net
```

## Usage

### Complete Private Network Setup
```hcl
module "private_network" {
  source = "../Modules/private_network"
  
  resource_group_name = "[orgPrefix]-[environment]"
  location           = "[location]"
  vnet_name          = "[orgPrefix]-[environment]-vnet"
  vnet_address_space = ["10.240.0.0/16"]

  subnets = {
    container_apps_infra = {
      name             = "snet-containerapps-infra"
      address_prefixes = ["10.240.0.0/23"]  # Dedicated for Container Apps
    }
    private_endpoints = {
      name              = "snet-private-endpoints"
      address_prefixes  = ["10.240.2.0/24"]
      service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.CognitiveServices"]
    }
  }
  
  private_endpoints = {
    storage = {
      name                           = "pe-[orgPrefix][environment]sa"
      private_connection_resource_id = azurerm_storage_account.main.id
      subresource_names              = ["blob"]
      private_dns_zone_name          = "privatelink.blob.core.windows.net"
    }
    keyvault = {
      name                           = "pe-[orgPrefix][environment]kv"
      private_connection_resource_id = azurerm_key_vault.main.id
      subresource_names              = ["vault"]
      private_dns_zone_name          = "privatelink.vaultcore.azure.net"
    }
    cosmosdb = {
      name                           = "pe-[orgPrefix]-[environment]-cosmos"
      private_connection_resource_id = azurerm_cosmosdb_account.main.id
      subresource_names              = ["sql"]
      private_dns_zone_name          = "privatelink.documents.azure.com"
    }
    cognitive_services = {
      name                           = "pe-[orgPrefix]-[environment]-cognitive"
      private_connection_resource_id = azurerm_cognitive_account.main.id
      subresource_names              = ["account"]
      private_dns_zone_name          = "privatelink.cognitiveservices.azure.com"
    }
    container_registry = {
      name                           = "pe-[orgPrefix][environment]acr"
      private_connection_resource_id = azurerm_container_registry.main.id
      subresource_names              = ["registry"]
      private_dns_zone_name          = "privatelink.azurecr.io"
    }
    container_app_environment = {
      name                           = "pe-[orgPrefix]-[environment]-cae"
      private_connection_resource_id = azurerm_container_app_environment.main.id
      subresource_names              = ["managedEnvironments"]
      private_dns_zone_name          = "privatelink.azurecontainerapps.io"
    }
    azure_frontdoor = {
      name                           = "pe-[orgPrefix]-frontdoor"
      private_connection_resource_id = azurerm_cdn_frontdoor_profile.main.id
      subresource_names              = ["azureFrontDoor"]
      private_dns_zone_name          = "privatelink.azurefd.net"
    }
  }
  
  tags = {
    Environment = "[environment]"
    Project     = "[orgPrefix]-demo"
    Security    = "private-only"
  }
}
```

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|----------|
| `resource_group_name` | Name of the resource group | `string` | n/a | yes |
| `location` | Azure region for the resources | `string` | n/a | yes |
| `vnet_name` | Name of the virtual network | `string` | n/a | yes |
| `vnet_address_space` | Address space for the virtual network | `list(string)` | `["10.240.0.0/16"]` | no |
| `subnets` | Map of subnets to create | `map(object)` | See variables.tf | no |
| `private_endpoints` | Map of private endpoints to create | `map(object)` | `{}` | no |
| `tags` | Tags to apply to all resources | `map(string)` | `{}` | no |

### Subnet Configuration

Default subnet configuration optimized for Container Apps and private endpoints:

```hcl
subnets = {
  container_apps_infra = {
    name             = "snet-containerapps-infra"
    address_prefixes = ["10.240.0.0/23"]  # /23 recommended for Container Apps
  }
  private_endpoints = {
    name              = "snet-private-endpoints"
    address_prefixes  = ["10.240.2.0/24"]
    service_endpoints = [
      "Microsoft.Storage",
      "Microsoft.KeyVault", 
      "Microsoft.CognitiveServices"
    ]
  }
}
```

### Private Endpoint Configuration

Each private endpoint requires:

```hcl
private_endpoints = {
  service_name = {
    name                           = "pe-{service-name}"           # Private endpoint name
    private_connection_resource_id = "{azure_resource.service.id}" # Resource ID to connect
    subresource_names              = ["subresource"]              # Service-specific subresource
    private_dns_zone_name          = "privatelink.{service}.net"  # Private DNS zone name
  }
}
```

## Outputs

| Name | Description |
|------|-------------|
| `vnet_id` | ID of the created virtual network |
| `subnet_ids` | Map of subnet keys to subnet IDs |
| `private_dns_zone_ids` | Map of DNS zone names to zone IDs |
| `private_endpoint_ids` | Map of private endpoint keys to endpoint IDs |

## Dependencies

This module depends on the following child modules:
- `../vnet` - Virtual network and subnets creation
- `../private_endpoint` - Individual private endpoint creation
- `../private_dns_zone` - Private DNS zones and VNet linking

## Container Apps Integration

When used with Container Apps Environment, the module provides:

### Infrastructure Subnet
- **Dedicated Subnet**: Container Apps require a dedicated subnet
- **Address Space**: /23 subnet recommended for Container Apps infrastructure
- **Internal Load Balancer**: Enabled for private-only access

### Private Endpoint for Container Apps Environment
```hcl
container_app_environment = {
  name                           = "pe-{container-app-environment-name}"
  private_connection_resource_id = azurerm_container_app_environment.main.id
  subresource_names              = ["managedEnvironments"]
  private_dns_zone_name          = "privatelink.azurecontainerapps.io"
}
```

### DNS Resolution
- **Private DNS Zone**: `privatelink.azurecontainerapps.io`
- **Automatic Linking**: DNS zone automatically linked to VNet
- **Internal Resolution**: Container Apps accessible only via private IP

## Security Benefits

### Zero Public Access
- **All Services Private**: Every service accessible only via private endpoints
- **VNet Isolation**: Complete network isolation within Virtual Network
- **DNS Security**: Private DNS zones prevent DNS leakage

### Network Segmentation
- **Dedicated Subnets**: Separate subnets for different workload types
- **Service Endpoints**: Additional security layer for supported services
- **Internal Load Balancer**: Container Apps use internal load balancer only

### Compliance Ready
- **Private Connectivity**: Meets enterprise security requirements
- **Network Controls**: Comprehensive network access controls
- **Audit Ready**: All network traffic is contained and auditable

## Best Practices

### Subnet Sizing
- **Container Apps**: Use /23 subnet (2,048 IPs) for Container Apps infrastructure
- **Private Endpoints**: Use /24 subnet (256 IPs) for private endpoints
- **Growth Planning**: Allow for additional private endpoints in the future

### DNS Management
- **Automatic Creation**: Let module create DNS zones automatically
- **VNet Linking**: Ensure proper VNet linking for DNS resolution
- **Custom Domains**: Consider custom subdomain requirements for AI services

### Monitoring
- **Network Flow Logs**: Enable for security monitoring
- **DNS Query Logs**: Monitor DNS resolution patterns
- **Private Endpoint Health**: Monitor private endpoint connectivity

## Troubleshooting

### Common Issues

#### DNS Resolution Problems
```
Error: cannot resolve private endpoint FQDN
```
**Solution**: Check private DNS zone VNet linking and ensure DNS zones are created

#### Container Apps Subnet Size
```
Error: subnet too small for Container Apps Environment
```
**Solution**: Use /23 subnet (2,048 IPs) minimum for Container Apps

#### Private Endpoint Connection
```
Error: private endpoint connection failed
```  
**Solution**: Verify resource ID and subresource names are correct

## Notes

- The module automatically creates private DNS zones based on the `private_dns_zone_name` specified in each private endpoint configuration
- Private endpoints are created in the "private_endpoints" subnet by default
- All resources inherit the tags specified in the module call
- Container Apps Environment requires dedicated infrastructure subnet
- Internal load balancer is automatically configured for Container Apps when private networking is enabled
- DNS zones are automatically linked to the Virtual Network for proper resolution
