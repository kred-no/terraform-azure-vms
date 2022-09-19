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
// Create root resources
//////////////////////////////////

locals {
  uid_seed      = join("", ["MakeSomethingUp", abspath(path.root)])
  uid           = substr(uuidv5("dns", local.uid_seed), 0, 6)
  location      = "West Europe"
  address_space = "192.168.0.0/24"
}

resource "azurerm_resource_group" "ROOT" {
  name     = join("-", ["terraform-azure-vms", "basic", local.uid])
  location = local.location
}

resource "azurerm_virtual_network" "ROOT" {
  name                = "demo-h8s"
  address_space       = [local.address_space]
  location            = azurerm_resource_group.ROOT.location
  resource_group_name = azurerm_resource_group.ROOT.name

}

//////////////////////////////////
// Module | Basic Example
//////////////////////////////////

module "BASIC" {
  source = "./../../../terraform-azure-vms"

  // Use "-target azurerm_virtual_network.ROOT" to deploy root-resources first
  resource_group  = azurerm_resource_group.ROOT
  virtual_network = azurerm_virtual_network.ROOT

  features = {
    create_vmss      = false
    create_lb_public = false
  }

  subnet = {
    name             = "demo-h8s-control"
    address_prefixes = toset([cidrsubnet(local.address_space, 3, 0)])
  }

  /*
  nat_pools = [{
    name                = "SSH"
    public              = true
    frontend_port_start = 50500
    frontend_port_end   = 50502
    backend_port        = 22
  }]*/
}
