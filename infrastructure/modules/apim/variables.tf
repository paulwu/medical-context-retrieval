# Variables
variable "apim_name" {
  description = "Name of the API Management instance"
  type        = string
  default     = "zavaqa-apim0812"
}

variable "location" {
  description = "Azure region for resources"
  type        = string
  default     = "West US 3"
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "tier" {
  description = "API Management tier"
  type        = string
  default     = "Developer"
}

variable "capacity" {
  description = "API Management capacity"
  type        = number
  default     = 1
}

variable "admin_email" {
  description = "Administrator email address"
  type        = string
  default     = "Paul.wu@microsoft.com"
}

variable "organization_name" {
  description = "Organization name"
  type        = string
  default     = "Zava"
}

variable "virtual_network_type" {
  description = "Virtual network type"
  type        = string
  default     = "None"
}

variable "app_insights_id" {
  description = "Application Insights resource ID"
  type        = string
}

variable "app_insights_name" {
  description = "Application Insights name"
  type        = string
}

variable "application_insights_instrumentation_key" {
  description = "Application Insights instrumentation key (legacy) to configure APIM logger"
  type        = string
  sensitive   = true
}

variable "log_analytics_workspace_id" {
  description = "Log Analytics workspace ID for diagnostic settings"
  type        = string
}
