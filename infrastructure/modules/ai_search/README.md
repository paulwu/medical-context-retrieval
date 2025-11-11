# AI Search Module

This module creates an Azure AI Search service with configurable settings.

## Features

- Azure AI Search service with configurable SKU
- Configurable replica and partition counts
- Network access control with IP allowlisting
- Semantic search support (free or standard)
- Local authentication control
- Comprehensive outputs for integration

## Usage

```hcl
module "ai_search" {
  source = "./modules/ai_search"

  search_service_name           = "my-search-service"
  resource_group_name           = "my-resource-group"
  location                      = "East US 2"
  sku_name                      = "standard"
  replica_count                 = 1
  partition_count               = 1
  public_network_access_enabled = true
  disable_local_auth            = false
  semantic_search_sku           = "free"
  
  tags = {
    Environment = "production"
    Project     = "MyProject"
  }
}
```

## Requirements

| Name | Version |
|------|---------|
| terraform | >= 1.0 |
| azurerm | >= 3.0 |

## Providers

| Name | Version |
|------|---------|
| azurerm | >= 3.0 |

## Inputs

| Name | Description | Type | Default | Required |
|------|-------------|------|---------|:--------:|
| search_service_name | Name of the Azure AI Search service | `string` | n/a | yes |
| resource_group_name | Name of the resource group | `string` | n/a | yes |
| location | Azure region where the AI Search service will be created | `string` | n/a | yes |
| sku_name | SKU name for the AI Search service | `string` | `"standard"` | no |
| replica_count | Number of replicas for the AI Search service | `number` | `1` | no |
| partition_count | Number of partitions for the AI Search service | `number` | `1` | no |
| public_network_access_enabled | Whether public network access is enabled | `bool` | `true` | no |
| disable_local_auth | Whether to disable local authentication | `bool` | `false` | no |
| semantic_search_sku | Semantic search SKU (free, standard) | `string` | `"free"` | no |
| hosting_mode | Hosting mode for the AI Search service | `string` | `"default"` | no |
| ip_rules | List of IP addresses or CIDR blocks that should be allowed | `list(string)` | `[]` | no |
| tags | Tags to apply to the AI Search service | `map(string)` | `{}` | no |

## Outputs

| Name | Description |
|------|-------------|
| search_service_id | ID of the AI Search service |
| search_service_name | Name of the AI Search service |
| search_service_url | URL of the AI Search service |
| search_service_endpoint | Endpoint of the AI Search service |
| search_service_primary_key | Primary admin key for the AI Search service |
| search_service_secondary_key | Secondary admin key for the AI Search service |
| search_service_query_keys | Query keys for the AI Search service |
| search_service_resource_group_name | Resource group name of the AI Search service |
| search_service_location | Location of the AI Search service |
| search_service_sku | SKU of the AI Search service |
| search_service_replica_count | Number of replicas for the AI Search service |
| search_service_partition_count | Number of partitions for the AI Search service |

## SKU Options

- `free` - Free tier (limited features)
- `basic` - Basic tier
- `standard` - Standard tier (recommended for production)
- `standard2` - Standard tier with more storage
- `standard3` - Standard tier with high performance
- `storage_optimized_l1` - Storage optimized L1
- `storage_optimized_l2` - Storage optimized L2

## Semantic Search

The module supports both free and standard semantic search:
- `free` - Limited semantic search capabilities
- `standard` - Full semantic search features (additional cost)