# Azure AI Foundry Module

This module provisions Azure AI Foundry accounts and projects with model deployments using modern Azure APIs and private networking integration.

## Architecture (v3.0)

This module uses the modern Azure AI Foundry approach with private networking support:
- `azapi_resource` for AI Foundry account with `kind="AIServices"`
- Support for AI Foundry projects via `azapi_resource`
- Model deployments using `azurerm_cognitive_deployment`
- **Private endpoint integration** via parent infrastructure
- **Custom subdomain support** for private DNS resolution

## What it creates

- **`azapi_resource.ai_foundry_account`**
	- Kind: "AIServices" (required for AI Foundry projects)
	- System-assigned managed identity
	- Configurable public network access (disabled when private networking is used)
	- `allowProjectManagement = true` for AI Foundry capabilities
	- `custom_subdomain_name = lower(cognitive_name)` for private DNS compatibility
- **`azapi_resource.ai_foundry_project`** (optional)
	- Machine Learning workspace configured as AI Foundry project
	- Links to the AI Foundry account as hub resource
	- Inherits private networking configuration from parent
- **`azurerm_cognitive_deployment`** (per item in `deployments`)
	- Uses the AI Foundry account as `cognitive_account_id`
	- Standard SKU by default
	- Supports models: GPT-4o-mini, DALL-E-3, Sora, and other OpenAI models

## Private Networking Integration

When used with the private networking infrastructure:
- **Private Endpoint**: Created automatically by parent infrastructure for `privatelink.cognitiveservices.azure.com`
- **DNS Resolution**: Custom subdomain enables private DNS resolution
- **Network Access**: Public network access disabled when `public_network_access_enabled = false`
- **Secure Connectivity**: All API calls route through private endpoints

## Requirements

- Terraform >= 1.5
- Providers:
	- `hashicorp/azurerm` = 4.19.0
	- `Azure/azapi`
- **Azure OpenAI Access**: Required for model deployments ([Request Access](https://aka.ms/oai/access))
- **Regional Quotas**: Ensure sufficient quota in target regions

## Inputs

| Variable | Type | Default | Description |
|----------|------|---------|-------------|
| `cognitive_name` | string | required | Name for the AI Foundry account |
| `resource_group_name` | string | required | Resource group name |
| `location` | string | required | Azure region |
| `public_network_access_enabled` | bool | `false` | Enable public network access (set to false for private endpoints) |
| `create_deployments` | bool | `true` | Whether to create model deployments |
| `create_ai_foundry_project` | bool | `true` | Whether to create AI Foundry project |
| `project_display_name` | string | `"AI Foundry Project"` | Display name for AI Foundry project |
| `project_description` | string | `"AI Foundry project"` | Description for AI Foundry project |
| `deployments` | list(object) | `[]` | List of model deployments to create |
| `tags` | map(string) | `{}` | Tags to apply to resources |

### Deployment Configuration

Each deployment item supports:

```hcl
deployments = [
	{
		name = "gpt-4o-mini"           # deployment name (if omitted, module uses model.name)
		model = {
			format          = "OpenAI"    # required by provider
			name            = "gpt-4o-mini"
			version         = "2024-07-18"
			rai_policy_name = "Microsoft.Default" # optional
		}
		sku = {
			name     = "GlobalStandard"  # Standard, GlobalStandard
			capacity = 1                 # TPM capacity (1 = 1K tokens per minute)
		}
	}
]
```

## Outputs

| Output | Type | Description |
|--------|------|-------------|
| `ai_foundry_account_name` | string | AI Foundry account name |
| `ai_foundry_account_id` | string | Resource ID for private endpoint creation |
| `ai_foundry_account_endpoint` | string | Endpoint URL (private when using private networking) |
| `ai_foundry_account_key` | string | Primary access key (sensitive) |
| `ai_foundry_project` | object | AI Foundry project details (if created) |

## Example Usage

### Basic AI Foundry with Model Deployments
```hcl
module "aifoundry_1" {
	source              = "./Modules/ai_foundry"
	resource_group_name = azurerm_resource_group.main.name
	location            = "[location1]"
	cognitive_name      = "[orgPrefix]-[environment]-aif1-[location1]"
	
	# Private networking (recommended)
	public_network_access_enabled = false
	
	deployments = [
		{
			name = "gpt-4o-mini"
			model = {
				format  = "OpenAI"
				name    = "gpt-4o-mini"
				version = "2024-07-18"
			}
			sku = {
				name     = "GlobalStandard"
				capacity = 1  # 1K TPM
			}
		}
	]
	
	tags = local.common_tags
}
```

### Multi-Region AI Foundry Setup
```hcl
# Primary region with image generation
```hcl
# Primary region with image models
module "aifoundry_primary" {
	source              = "./Modules/ai_foundry"
	resource_group_name = azurerm_resource_group.main.name
	location            = "[location1]"
	cognitive_name      = "[orgPrefix]-[environment]-aif1-[location1]"
	
	deployments = [
		{
			name = "gpt-image-1"
			model = {
				format          = "OpenAI"
				name            = "gpt-image-1"
				version         = "2025-04-15"
				rai_policy_name = "Microsoft.Default"
			}
		}
	]
}

# Secondary region with realtime models
module "aifoundry_secondary" {
	source              = "./Modules/ai_foundry"
	resource_group_name = azurerm_resource_group.main.name
	location            = "[location2]"
	cognitive_name      = "[orgPrefix]-[environment]-aif2-[location2]"
	
	deployments = [
		{
			name = "gpt-4o-mini-realtime-preview"
			model = {
				format  = "OpenAI"
				name    = "gpt-4o-mini-realtime-preview"
				version = "2024-12-17"
			}
			sku = {
				name     = "GlobalStandard"
				capacity = 6  # 6K TPM for realtime
			}
		}
	]
}
```

## Model Support

### Currently Supported Models
- **GPT-4o-mini**: Text generation (`2024-07-18`)
- **GPT-4o-mini-realtime-preview**: Real-time conversation (`2024-12-17`)
- **DALL-E-3 (gpt-image-1)**: Image generation (`2025-04-15`)
- **Sora**: Video generation (`2025-05-02`) - Requires preview access

### Regional Model Availability
Different models are available in different regions:
- **West US 3**: GPT-4o-mini, DALL-E-3
- **Sweden Central**: GPT-4o-mini-realtime-preview
- **East US 2**: General model availability

Use the provided PowerShell scripts to check model availability:
```powershell
# Check available models and quotas
.\Scripts\Get-Availability-Quotas.ps1
```

## Private Networking Integration

When deployed with private networking:

### Private Endpoint Creation
```hcl
# Parent infrastructure creates private endpoints
private_endpoints = {
  aifoundry1 = {
    name                           = "pe-${module.aifoundry_1.ai_foundry_account_name}"
    private_connection_resource_id = module.aifoundry_1.ai_foundry_account_id
    subresource_names              = ["account"]
    private_dns_zone_name          = "privatelink.cognitiveservices.azure.com"
  }
}
```

### DNS Configuration
- **Custom Subdomain**: Automatically configured based on `cognitive_name`
- **Private DNS Zone**: `privatelink.cognitiveservices.azure.com`
- **Resolution**: All API calls resolve to private IP addresses

## Troubleshooting

### Common Issues

#### Quota Exceeded
```
Error: insufficient quota for requested model deployment
```
**Solution**: Use the quota checking script and request quota increase if needed:
```powershell
.\Scripts\Get-Availability-Quotas.ps1
```

#### Model Not Available in Region
```
Error: model 'gpt-4o-mini-realtime-preview' not available in location 'westus3'
```
**Solution**: Check regional availability and update deployment configuration:
```powershell
.\Scripts\Get-Available-Models.ps1
```

#### Private Endpoint DNS Resolution
```
Error: cannot resolve cognitive account endpoint
```
**Solution**: Ensure private DNS zone is properly configured and linked to VNet.

## Best Practices

### Security
- ✅ **Disable Public Access**: Set `public_network_access_enabled = false`
- ✅ **Use Private Endpoints**: Always deploy with private networking
- ✅ **Managed Identity**: Leverage system-assigned managed identity
- ✅ **Custom Subdomain**: Required for private DNS resolution

### Performance
- ✅ **Regional Deployment**: Deploy models in regions closest to users
- ✅ **Capacity Planning**: Monitor usage and adjust TPM capacity as needed
- ✅ **Model Selection**: Choose appropriate models for each use case

### Cost Management
- ✅ **Right-size Capacity**: Start with minimal capacity and scale up
- ✅ **Monitor Usage**: Use Application Insights for usage tracking
- ✅ **Regional Pricing**: Consider pricing differences between regions

## Version History

- **v3.0**: Added private networking support, enhanced model configuration
- **v2.0**: Modern Azure AI Foundry approach with azapi_resource
- **v1.0**: Initial implementation with azurerm_cognitive_account

## Notes

- Uses `kind="AIServices"` which is required for AI Foundry project compatibility
- Ensure you have access/quota for the requested models in the chosen region(s)
- Public network access is automatically disabled when used with private networking
- AI Foundry projects provide enhanced AI development capabilities
- Custom subdomains enable proper private DNS resolution for private endpoints
