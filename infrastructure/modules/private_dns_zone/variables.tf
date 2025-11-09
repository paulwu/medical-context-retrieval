variable "zone_name" { type = string }
variable "resource_group_name" { type = string }

variable "virtual_network_ids" {
	type    = map(string)
	default = {}
}

variable "tags" {
	type    = map(string)
	default = {}
}
