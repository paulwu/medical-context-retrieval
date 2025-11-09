variable "profile_name" {
	type = string
}

variable "resource_group_name" {
	type = string
}
variable "sku_name" {
	type    = string
	default = "Standard_AzureFrontDoor"
}
variable "endpoint_name" {
	type = string
}
variable "origin_host_name" {
	type        = string
	description = "Public hostname of the origin (e.g. <containerapp>.<region>.azurecontainerapps.io or private resolver)."
}
variable "origin_host_header" {
	type    = string
	default = ""
}
variable "health_probe_path" {
	type    = string
	default = "/"
}
variable "origin_protocol" {
	type    = string
	default = "Https"
}
variable "tags" {
	type    = map(string)
	default = {}
}
