# AI Search Module - Variables

variable "search_service_name" {
  description = "Name of the Azure AI Search service"
  type        = string
}

variable "location" {
  description = "Azure region where the AI Search service will be created"
  type        = string
}

variable "resource_group_name" {
  description = "Name of the resource group"
  type        = string
}

variable "sku_name" {
  description = "SKU name for the AI Search service"
  type        = string
  default     = "standard"
  
  validation {
    condition     = contains(["free", "basic", "standard", "standard2", "standard3", "storage_optimized_l1", "storage_optimized_l2"], var.sku_name)
    error_message = "SKU name must be one of: free, basic, standard, standard2, standard3, storage_optimized_l1, storage_optimized_l2."
  }
}

variable "replica_count" {
  description = "Number of replicas for the AI Search service"
  type        = number
  default     = 1
  
  validation {
    condition     = var.replica_count >= 1 && var.replica_count <= 12
    error_message = "Replica count must be between 1 and 12."
  }
}

variable "partition_count" {
  description = "Number of partitions for the AI Search service"
  type        = number
  default     = 1
  
  validation {
    condition     = contains([1, 2, 3, 4, 6, 12], var.partition_count)
    error_message = "Partition count must be one of: 1, 2, 3, 4, 6, 12."
  }
}

variable "public_network_access_enabled" {
  description = "Whether public network access is enabled"
  type        = bool
  default     = true
}

variable "disable_local_auth" {
  description = "Whether to disable local authentication"
  type        = bool
  default     = false
}

variable "semantic_search_sku" {
  description = "Semantic search SKU (free, standard)"
  type        = string
  default     = "free"
  
  validation {
    condition     = contains(["free", "standard"], var.semantic_search_sku)
    error_message = "Semantic search SKU must be either 'free' or 'standard'."
  }
}

variable "hosting_mode" {
  description = "Hosting mode for the AI Search service"
  type        = string
  default     = "default"
  
  validation {
    condition     = contains(["default", "highDensity"], var.hosting_mode)
    error_message = "Hosting mode must be either 'default' or 'highDensity'."
  }
}

variable "ip_rules" {
  description = "List of IP addresses or CIDR blocks that should be allowed to access the service"
  type        = list(string)
  default     = []
}

variable "tags" {
  description = "Tags to apply to the AI Search service"
  type        = map(string)
  default     = {}
}