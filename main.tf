//////////////////////////////////
// Helper variable(s)
//////////////////////////////////

locals {
  // Generate list of VM instances
  vm_list = formatlist("%s", range(0, var.cfg["vm_instances"]))
}

//////////////////////////////////
// Parent Resources
//////////////////////////////////

data "azurerm_resource_group" "MAIN" {
  name = var.parent_resources["resource_group_name"]
}

data "azurerm_virtual_network" "MAIN" {
  name                = var.parent_resources["virtual_network_name"]
  resource_group_name = data.azurerm_resource_group.MAIN.name
}

//////////////////////////////////
// Network | Subnet
//////////////////////////////////

resource "azurerm_subnet" "MAIN" {
  name                 = var.cfg["subnet_name"]
  address_prefixes     = var.cfg["subnet_prefixes"]
  resource_group_name  = data.azurerm_resource_group.MAIN.name
  virtual_network_name = data.azurerm_virtual_network.MAIN.name
}

//////////////////////////////////
// Network | Security Group
//////////////////////////////////

resource "azurerm_network_security_group" "MAIN" {
  name                = join("-",[var.cfg["prefix"],"nsg"])
  location            = data.azurerm_resource_group.MAIN.location
  resource_group_name = data.azurerm_resource_group.MAIN.name
}

resource "azurerm_subnet_network_security_group_association" "MAIN" {
  subnet_id                 = azurerm_subnet.MAIN.id
  network_security_group_id = azurerm_network_security_group.MAIN.id
}

//////////////////////////////////
// Network | Application Security Group 
//////////////////////////////////

resource "azurerm_application_security_group" "MAIN" {
  name                = join("-", [var.cfg["prefix"], "asg"])
  location            = data.azurerm_resource_group.MAIN.location
  resource_group_name = data.azurerm_resource_group.MAIN.name
}

//////////////////////////////////
// Load Balancer 
//////////////////////////////////

//////////////////////////////////
// Load Balancer | Backend Pool
//////////////////////////////////

//////////////////////////////////
// Load Balancer  | LB Rules
//////////////////////////////////

//////////////////////////////////
// Load Balancer | NAT Rules
//////////////////////////////////

//////////////////////////////////
// Virtual Machine | Availability Set
//////////////////////////////////

resource "azurerm_availability_set" "MAIN" {
  name                = join("-", [var.cfg["prefix], "vmas"])
  location            = data.azurerm_resource_group.MAIN.location
  resource_group_name = data.azurerm_resource_group.MAIN.name
}

//////////////////////////////////
// Virtual Machine | Network Interface
//////////////////////////////////

resource "azurerm_network_interface" "MAIN" {
  for_each = {
    for idx,vm in local.vm_list: idx => vm
  }

  name                = join("-", [var.cfg["prefix], "nic", each.key])
  location            = data.azurerm_resource_group.MAIN.location
  resource_group_name = data.azurerm_resource_group.MAIN.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.MAIN.id
    private_ip_address_allocation = "Dynamic"
  }
}

//////////////////////////////////
// Virtual Machine
//////////////////////////////////

resource "azurerm_linux_virtual_machine" "MAIN" {
  for_each = {
    for idx,vm in local.vm_list: idx => vm
  }

  name                = join("-", [var.cfg["prefix], each.key])
  location            = data.azurerm_resource_group.MAIN.location
  resource_group_name = data.azurerm_resource_group.MAIN.name
  size                = "Standard_F2"
  admin_username      = "adminuser"
  
  network_interface_ids = [
    azurerm_network_interface.MAIN[each.key].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Debian"
    offer     = "debian-11"
    sku       = "11"
    version   = "latest"
  }
}
