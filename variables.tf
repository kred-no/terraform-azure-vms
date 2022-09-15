variable "parent_resources" {
  description = "TODO"

  type = object({
    resource_group_name  = string
    virtual_network_name = string
  })
}

variable "cfg" {
  type = object({
    prefix          = string
    subnet_name     = string
    subnet_prefixes = set(string)
    vm_instances    = optional(number, 1)
    vm_size         = optional(string, "Standard_F2")
    vm_username     = optional(string, "batman")
    vm_password     = optional(string, "B@tCav3")
  })
}