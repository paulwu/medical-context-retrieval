# Variables for Container App Environment Module

# Container App Environment Configuration
variable "container_app_environment_name" {
  description = "Name of the Container App Environment"
  type        = string
}

variable "location" {
  description = "Azure region for the resources"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "infrastructure_subnet_id" {
  description = "Subnet ID for Container Apps infrastructure"
  type        = string
  default     = null
}

variable "internal_load_balancer_enabled" {
  description = "Enable internal load balancer for private networking"
  type        = bool
  default     = false
}

variable "log_analytics_workspace_customer_id" {
  description = "The customer ID (GUID) of the Log Analytics workspace for Container App Environment logs"
  type        = string
  default     = null
}

variable "log_analytics_workspace_shared_key" {
  description = "The shared key of the Log Analytics workspace for Container App Environment logs"
  type        = string
  sensitive   = true
  default     = null
}

variable "log_analytics_workspace_id" {
  description = "The resource ID of the Log Analytics workspace for diagnostic settings"
  type        = string
  default     = null
}

variable "tags" {
  description = "Tags to apply to all resources"
  type        = map(string)
  default     = {}
}

# Workload Profile Configuration
variable "enable_dedicated_workload_profiles" {
  description = "Enable dedicated workload profiles (required for private networking)"
  type        = bool
  default     = false
}

variable "dedicated_workload_profile_name" {
  description = "Name of the dedicated workload profile"
  type        = string
  default     = "D4"
}

variable "dedicated_workload_profile_type" {
  description = "Type of the dedicated workload profile"
  type        = string
  default     = "D4"
}

variable "dedicated_workload_profile_min_count" {
  description = "Minimum count for dedicated workload profile"
  type        = number
  default     = 1
}

variable "dedicated_workload_profile_max_count" {
  description = "Maximum count for dedicated workload profile"
  type        = number
  default     = 3
}

# Container App Configuration
variable "deploy_helloworld_app" {
  description = "Deploy the Hello World demo container app"
  type        = bool
  default     = false
}

variable "container_app_name" {
  description = "Name of the Container App"
  type        = string
  default     = "helloworld-app"
}

variable "container_app_container_name" {
  description = "Name of the container within the Container App"
  type        = string
  default     = "demo-app"
}

variable "container_app_image" {
  description = "Container image to deploy"
  type        = string
  default     = "nginxdemos/hello:latest"
}

variable "container_app_cpu" {
  description = "CPU allocation for the container"
  type        = number
  default     = 0.25
}

variable "container_app_memory" {
  description = "Memory allocation for the container"
  type        = string
  default     = "0.5Gi"
}

variable "container_app_min_replicas" {
  description = "Minimum number of replicas"
  type        = number
  default     = 1
}

variable "container_app_max_replicas" {
  description = "Maximum number of replicas"
  type        = number
  default     = 10
}

# Environment Variables and Secrets
variable "container_app_env_vars" {
  description = "Environment variables for the container app"
  type = list(object({
    name        = string
    value       = optional(string)
    secret_name = optional(string)
  }))
  default = []
}

variable "container_app_secrets" {
  description = "Secrets for the container app"
  type = list(object({
    name  = string
    value = string
  }))
  default = []
}

# Ingress Configuration
variable "enable_ingress" {
  description = "Enable ingress for the container app"
  type        = bool
  default     = true
}

variable "ingress_allow_insecure_connections" {
  description = "Allow insecure connections for ingress"
  type        = bool
  default     = false
}

variable "ingress_external_enabled" {
  description = "Enable external access for ingress"
  type        = bool
  default     = true
}

variable "ingress_target_port" {
  description = "Target port for ingress traffic"
  type        = number
  default     = 80
}
