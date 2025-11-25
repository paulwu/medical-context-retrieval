terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 4.0"
    }
  }
}

# Azure Front Door (Standard/Premium) using azurerm_cdn_frontdoor_profile + endpoints + routes + origins
# This module intentionally keeps scope minimal; caller wires container app hostname/origin.

resource "azurerm_cdn_frontdoor_profile" "this" {
  name                = var.profile_name
  resource_group_name = var.resource_group_name
  sku_name            = var.sku_name
  tags                = var.tags

  identity {
    type = "SystemAssigned"
  }
}

resource "azurerm_cdn_frontdoor_origin_group" "default" {
  name                     = "og-${var.profile_name}"
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id

  load_balancing {
    sample_size                 = 4
    successful_samples_required = 3
  }

  health_probe {
    interval_in_seconds = 30
    path                = var.health_probe_path
    protocol            = var.origin_protocol
    request_type        = "GET"
  }
}

resource "azurerm_cdn_frontdoor_endpoint" "this" {
  name                     = var.endpoint_name
  cdn_frontdoor_profile_id = azurerm_cdn_frontdoor_profile.this.id
  tags                     = var.tags
}

resource "azurerm_cdn_frontdoor_origin" "app" {
  name                           = "origin-app"
  cdn_frontdoor_origin_group_id  = azurerm_cdn_frontdoor_origin_group.default.id
  enabled                        = true
  certificate_name_check_enabled = true

  host_name          = var.origin_host_name
  http_port          = 80
  https_port         = 443
  origin_host_header = var.origin_host_header != "" ? var.origin_host_header : var.origin_host_name
  priority           = 1
  weight             = 1000
}

resource "azurerm_cdn_frontdoor_route" "app" {
  name                          = "route-app"
  cdn_frontdoor_endpoint_id     = azurerm_cdn_frontdoor_endpoint.this.id
  cdn_frontdoor_origin_group_id = azurerm_cdn_frontdoor_origin_group.default.id
  cdn_frontdoor_origin_ids      = [azurerm_cdn_frontdoor_origin.app.id]
  supported_protocols           = ["Http", "Https"]
  patterns_to_match             = ["/*"]
  forwarding_protocol           = "MatchRequest"  #HttpsOnly
  https_redirect_enabled        = true
  link_to_default_domain        = true
  enabled                       = true
  depends_on                    = [azurerm_cdn_frontdoor_origin.app]
}

