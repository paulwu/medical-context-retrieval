# Variables for the private_network module

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "location" {
  description = "Azure region for the resources"
  type        = string
}

variable "vnet_name" {
  description = "Name of the virtual network"
  type        = string
}

variable "vnet_address_space" {
  description = "Address space for the virtual network"
  type        = list(string)
  default     = ["10.240.0.0/16"]
}

variable "subnets" {
  description = "Map of subnets to create"
  type = map(object({
    name             = string
    address_prefixes = list(string)
    service_endpoints = optional(list(string), [])
    delegation = optional(object({
      name = string
      service_delegation = object({
        name    = string
        actions = optional(list(string))
      })
    }))
  }))
  default = {
    container_apps_infra = {
      name             = "snet-containerapps-infra"
      address_prefixes = ["10.240.0.0/23"]
    }
    private_endpoints = {
      name             = "snet-private-endpoints"
      address_prefixes = ["10.240.2.0/24"]
      service_endpoints = ["Microsoft.Storage", "Microsoft.KeyVault", "Microsoft.CognitiveServices"]
    }
  }
}

variable "private_endpoints" {
  description = "Map of private endpoints to create"
  type = map(object({
    name                           = string
    private_connection_resource_id = string
    subresource_names              = list(string)
    private_dns_zone_name          = string
  }))
  default = {}
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

variable "depends_on_resources" {
  description = "List of resources this module depends on"
  type        = list(any)
  default     = []
}
