//////////////////////////////////
// Required variables
//////////////////////////////////

variable "resource_group" {
  description = "Resource group to use. If 'id' is present, then resource is not created."

  type = object({
    name     = string
    id       = optional(string, "")
    location = optional(string, "")
  })
}

variable "virtual_network" {
  description = "Virtual Network to use. If 'id' is present, then resource is not created."

  type = object({
    name          = string
    id            = optional(string, "")
    address_space = optional(set(string), [])
  })
}

variable "subnet" {
  description = "Subnet to use. If 'id' is present, then resource is not created."

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
  description = "Prefix for module resources in the the resource group."

  type    = string
  default = "tfvm"
}

variable "features" {
  description = <<-HEREDOC
  Configure the module features.
  
  * create_nsg: true | (false)
    |- Create and assign a Network Security Group for the scale-set.
  * create_lb_internal:  true | (false)
    |- Create and assign an internal load-balancer for the scale-set.
  * create_lb_public: true | (false)
    |- Create and assign a public load-balancer for the scale-set (incl. a public IP-address).
  * create_vmss: (true) | false
    |- Create the scale-set VMs.
  HEREDOC

  type = object({
    create_nsg         = optional(bool, false)
    create_lb_internal = optional(bool, false)
    create_lb_public   = optional(bool, false)
    create_vmss        = optional(bool, true)
  })

  default = {}
}

variable "tags" {
  description = "Tags to assign module resources in the resource group."

  type    = map(string)
  default = {}
}

variable "nsg_rules" {
  description = "Rules for the VMSS Network Security Group (if enabled)."

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
  description = "Rules for the load-balancer(s), if enabled. 'internal' & 'external' assigns to corresponding load-balancer."

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
  description = "NAT Pools for the load-balancer(s), if enabled. 'internal' & 'external' assigns to corresponding load-balancer."

  type = list(object({
    name                = string
    internal            = optional(bool, false)
    public              = optional(bool, false)
    protocol            = optional(string, "Tcp")
    frontend_port_start = number
    frontend_port_end   = number
    backend_port        = number
  }))

  default = []
}

variable "vmss" {
  description = "Customize the VM Scale-Set."

  type = object({
    os              = optional(string, "linux")
    sku             = optional(string, "Standard_B1ms")
    admin_username  = optional(string, "batman")
    admin_password  = optional(string, "TheB@tM0bile")
    instances       = optional(number, 1)
    overprovision   = optional(bool, false)
    hostname        = optional(string)
    priority        = optional(string)
    eviction_policy = optional(string)
    max_bid_price   = optional(number)
    image_publisher = optional(string, "Debian")
    image_offer     = optional(string, "debian-11")
    image_sku       = optional(string, "11")
    image_version   = optional(string, "latest")
  })

  default = {}
}
