# (Instrumentation key now passed in via variable; data source removed)

# API Management Service
resource "azurerm_api_management" "apim" {
  name                = var.apim_name
  location            = var.location
  resource_group_name = var.resource_group_name
  publisher_name      = var.organization_name
  publisher_email     = var.admin_email
  sku_name           = "${var.tier}_${var.capacity}"

  identity {
    type = "SystemAssigned"
  }

  tags = {
    "Created by" = "paulwu@onemtc.net"
  }
}

# Application Insights Logger
resource "azurerm_api_management_logger" "app_insights_logger" {
  name                = var.app_insights_name
  api_management_name = azurerm_api_management.apim.name
  resource_group_name = var.resource_group_name

  application_insights {
    instrumentation_key = var.application_insights_instrumentation_key
  }
}

# API Management Diagnostic Settings
resource "azurerm_api_management_diagnostic" "app_insights_diagnostic" {
  identifier               = "applicationinsights"
  resource_group_name      = var.resource_group_name
  api_management_name      = azurerm_api_management.apim.name
  api_management_logger_id = azurerm_api_management_logger.app_insights_logger.id

  sampling_percentage       = 100.0
  always_log_errors        = true
  log_client_ip            = true
  verbosity                = "information"
  http_correlation_protocol = "Legacy"

  frontend_request {
    body_bytes = 0
    headers_to_log = []
  }

  frontend_response {
    body_bytes = 0
    headers_to_log = []
  }

  backend_request {
    body_bytes = 0
    headers_to_log = []
  }

  backend_response {
    body_bytes = 0
    headers_to_log = []
  }
}

# Monitor Diagnostic Setting for APIM
resource "azurerm_monitor_diagnostic_setting" "apim_diagnostics" {
  name               = "default"
  target_resource_id = azurerm_api_management.apim.id
  log_analytics_workspace_id = var.log_analytics_workspace_id
  log_analytics_destination_type = "Dedicated"

  enabled_log {
    category = "GatewayLogs"
  }

  enabled_log {
    category = "WebSocketConnectionLogs"
  }

  metric {
    category = "AllMetrics"
    enabled  = false
  }
}