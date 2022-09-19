//////////////////////////////////
// Required variables
//////////////////////////////////

variable "resource_group" {
  description = ""

  type = object({
    name     = string
    id       = optional(string, "")
    location = optional(string, "")
  })
}

variable "virtual_network" {
  description = ""

  type = object({
    name          = string
    id            = optional(string, "")
    address_space = optional(set(string), [])
  })
}

variable "subnet" {
  description = ""

  type = object({
    name             = string
    id               = optional(string, "")
    address_prefixes = optional(set(string), [])
  })
}

//////////////////////////////////
// Optional variables
//////////////////////////////////

variable "prefix" {
  description = ""

  type    = string
  default = "tfvmss"
}

variable "features" {
  description = ""

  type = object({
    create_nsg         = optional(bool, false)
    create_lb_internal = optional(bool, false)
    create_lb_public   = optional(bool, false)
    create_vmss        = optional(bool, false)
  })

  default = {}
}

variable "tags" {
  description = ""

  type    = map(string)
  default = {}
}

variable "nsg_rules" {
  description = ""

  type = set(object({
    name                         = string
    priority                     = number
    direction                    = optional(string, "Inbound")
    access                       = optional(string, "Allow")
    protocol                     = optional(string, "Tcp")
    source_port_range            = optional(string)
    source_port_ranges           = optional(set(string), [])
    source_address_prefix        = optional(string, "")
    source_address_prefixes      = optional(set(string), [])
    destination_port_range       = optional(string, "")
    destination_port_ranges      = optional(set(string), [])
    destination_address_prefix   = optional(string, "")
    destination_address_prefixes = optional(set(string), [])
  }))

  default = []
}

variable "lb_rules" {
  description = ""

  type = set(object({
    name               = string
    internal           = optional(bool, false)
    public             = optional(bool, false)
    frontend_port      = number
    backend_port       = number
    load_distribution  = optional(string, "Default")
    protocol           = optional(string, "Tcp")
    number_of_probes   = optional(number, 0)
    probe_port         = optional(number)
    probe_protocol     = optional(string)
    probe_interval     = optional(number)
    probe_request_path = optional(string)
  }))

  default = []
}


variable "nat_pools" {
  description = ""

  type = list(object({
    name                = string
    internal            = optional(bool, false)
    public              = optional(bool, false)
    frontend_port_start = number
    frontend_port_end   = number
    backend_port        = number
    protocol            = optional(string, "Tcp")
  }))

  default = []
}

variable "vmss" {
  description = ""

  type = object({
    os              = optional(string, "linux")
    hostname        = optional(string)
    sku             = optional(string, "Standard_B1ms")
    instances       = optional(number, 1)
    admin_username  = optional(string, "batman")
    admin_password  = optional(string, "TheB@tM0bile")
    priority        = optional(string)
    eviction_policy = optional(string)
    max_bid_price   = optional(number)
    overprovision   = optional(bool)
    image_publisher = optional(string, "Debian")
    image_offer     = optional(string, "debian-11")
    image_sku       = optional(string, "11")
    image_version   = optional(string, "latest")
  })

  default = {}
}
