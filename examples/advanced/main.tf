//////////////////////////////////
// Provider
//////////////////////////////////

terraform {
  required_version = ">= 1.3.0"

  required_providers {
    azurerm = {
      source = "hashicorp/azurerm"
    }
  }
}

provider "azurerm" {
  features {}
}

//////////////////////////////////
// Custom settings
//////////////////////////////////

locals {
  uid_seed      = join("", ["MakeSomethingUp", abspath(path.root)])
  uid           = substr(uuidv5("dns", local.uid_seed), 0, 6)
  location      = "West Europe"
  address_space = "192.168.1.0/24"
}

//////////////////////////////////
// Root resources
//////////////////////////////////

resource "azurerm_resource_group" "ROOT" {
  name     = join("-", ["terraform-azure-vms", "advanced", local.uid])
  location = local.location
}

resource "azurerm_virtual_network" "ROOT" {
  name                = "demo-h8s"
  address_space       = [local.address_space]
  location            = azurerm_resource_group.ROOT.location
  resource_group_name = azurerm_resource_group.ROOT.name

}

//////////////////////////////////
// Module | Advanced Example
//////////////////////////////////

module "ADVANCED" {
  source = "./../../../terraform-azure-vms"

  prefix = "Demo"

  // Use "-target azurerm_virtual_network.ROOT" to deploy root-resources first
  resource_group  = azurerm_resource_group.ROOT
  virtual_network = azurerm_virtual_network.ROOT

  features = {
    create_nsg         = true
    create_lb_internal = true
    create_lb_public   = true
    create_vmss        = true
  }

  subnet = {
    name             = "demo-hashi8s-control"
    address_prefixes = toset([cidrsubnet(local.address_space, 3, 0)])
  }

  tags = {
    Environment = "Demo"
  }

  nsg_rules = [{
    name                   = "AllowWeb"
    priority               = 499
    source_port_range      = "*"
    source_address_prefix  = "*"
    destination_port_range = "80"
    }, {
    name                   = "AllowWebSecure"
    priority               = 498
    source_port_range      = "*"
    source_address_prefix  = "*"
    destination_port_range = "443"
    }, {
    name                   = "AllowSSH"
    priority               = 497
    source_port_range      = "*"
    source_address_prefix  = "*"
    destination_port_range = "22"
  }]

  lb_rules = [{
    name             = "Web"
    public           = true
    internal         = true
    frontend_port    = 80
    backend_port     = 80
    number_of_probes = 1
    }, {
    name             = "WebSecure"
    public           = true
    frontend_port    = 443
    backend_port     = 443
    number_of_probes = 1
  }]

  nat_pools = [{
    name                = "SSH"
    internal            = true
    public              = true
    frontend_port_start = 50500
    frontend_port_end   = 50506
    backend_port        = 22
  }]

  vmss = {
    sku             = "Standard_B1ms"
    instances       = 3
    image_publisher = "Canonical"
    image_offer     = "0001-com-ubuntu-server-jammy"
    image_sku       = "22_04-lts"
    image_version   = "latest"
  }
}
