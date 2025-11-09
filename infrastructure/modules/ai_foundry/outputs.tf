# Data source to get the keys for the AI Foundry account
data "azapi_resource_action" "ai_foundry_account_keys" {
  type                   = "Microsoft.CognitiveServices/accounts@2025-06-01"
  resource_id           = azapi_resource.ai_foundry_account.id
  action                = "listKeys"
  response_export_values = ["*"]
}

# Output the primary access key of the Cognitive Services account
output "ai_foundry_account_key" {
  value = data.azapi_resource_action.ai_foundry_account_keys.output.key1
  description = "Primary access key of the AI Foundry account"
  sensitive = true
}

# Output the name of the Cognitive Services account
output "ai_foundry_account_name" {
  value = azapi_resource.ai_foundry_account.name
  description = "Name of the AI Foundry account"
}

# Output the ID of the Cognitive Services account
output "ai_foundry_account_id" {
  value = azapi_resource.ai_foundry_account.id
  description = "ID of the AI Foundry account"
}

# Output the endpoint of the Cognitive Services account
output "ai_foundry_account_endpoint" {
  value = azapi_resource.ai_foundry_account.output.properties.endpoint
  description = "Endpoint URL of the AI Foundry account"
}

# Output the AI Foundry project information (if created)
output "ai_foundry_project" {
  value = var.create_ai_foundry_project ? {
    id   = azapi_resource.ai_foundry_project[0].id
    name = azapi_resource.ai_foundry_project[0].name
  } : null
  description = "AI Foundry project details"
}
