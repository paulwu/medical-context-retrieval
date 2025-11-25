# AI Search Module - Main Configuration

# Azure AI Search Service
resource "azurerm_search_service" "main" {
  name                          = var.search_service_name
  resource_group_name           = var.resource_group_name
  location                      = var.location
  sku                           = var.sku_name
  replica_count                 = var.replica_count
  partition_count               = var.partition_count
  hosting_mode                  = var.hosting_mode
  public_network_access_enabled = var.public_network_access_enabled
  local_authentication_enabled  = !var.disable_local_auth
  semantic_search_sku           = var.semantic_search_sku

  # Authentication options
  authentication_failure_mode = "http403"

  # Network rule set for IP restrictions
  allowed_ips = var.ip_rules

  tags = var.tags

  # Lifecycle management
  lifecycle {
    prevent_destroy = false
  }

  timeouts {
    create = "30m"
    read   = "5m"
    update = "30m"
    delete = "30m"
  }
}