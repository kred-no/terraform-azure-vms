locals {
  frontend_ip_configuration_name = "LoadBalancerFEIP"
  backend_address_pool_name      = "LoadBalancerBEAP"
  vmss_nic_name                  = "primary" //force replacement; lb-bug?
}

//////////////////////////////////
/// Resource Group
//////////////////////////////////

resource "azurerm_resource_group" "MAIN" {
  count = length(var.resource_group.id) > 0 ? 0 : 1

  name     = var.resource_group.name
  location = var.resource_group.location
  tags     = var.tags
}

data "azurerm_resource_group" "MAIN" {
  depends_on = [
    azurerm_resource_group.MAIN,
  ]

  name = var.resource_group.name
}

//////////////////////////////////
/// Virtual Network
//////////////////////////////////

resource "azurerm_virtual_network" "MAIN" {
  count = length(var.virtual_network.id) > 0 ? 0 : 1

  depends_on = [
    azurerm_resource_group.MAIN,
  ]

  name                = var.virtual_network.name
  address_space       = var.virtual_network.address_space
  location            = data.azurerm_resource_group.MAIN.location
  resource_group_name = data.azurerm_resource_group.MAIN.name
  tags                = var.tags
}

data "azurerm_virtual_network" "MAIN" {
  depends_on = [
    azurerm_resource_group.MAIN,
    azurerm_virtual_network.MAIN
  ]

  name                = var.virtual_network.name
  resource_group_name = data.azurerm_resource_group.MAIN.name
}

//////////////////////////////////
/// Subnet
//////////////////////////////////

resource "azurerm_subnet" "MAIN" {
  count = length(var.subnet.id) > 0 ? 0 : 1

  depends_on = [
    azurerm_resource_group.MAIN,
    azurerm_virtual_network.MAIN,
  ]

  name                 = var.subnet.name
  address_prefixes     = var.subnet.address_prefixes
  resource_group_name  = data.azurerm_resource_group.MAIN.name
  virtual_network_name = data.azurerm_virtual_network.MAIN.name
}

data "azurerm_subnet" "MAIN" {
  depends_on = [
    azurerm_resource_group.MAIN,
    azurerm_virtual_network.MAIN,
    azurerm_subnet.MAIN,
  ]

  name                 = var.subnet.name
  virtual_network_name = data.azurerm_virtual_network.MAIN.name
  resource_group_name  = data.azurerm_resource_group.MAIN.name
}

//////////////////////////////////
/// Application Security Group
//////////////////////////////////

resource "azurerm_application_security_group" "MAIN" {
  name                = join("-", [var.prefix, "asg"])
  location            = data.azurerm_resource_group.MAIN.location
  resource_group_name = data.azurerm_resource_group.MAIN.name
  tags                = var.tags
}

//////////////////////////////////
// Network Security Group
//////////////////////////////////

resource "azurerm_network_security_group" "MAIN" {
  count = var.features.create_nsg ? 1 : 0

  name                = join("-", [var.prefix, "nsg"])
  location            = data.azurerm_resource_group.MAIN.location
  resource_group_name = data.azurerm_resource_group.MAIN.name

  dynamic "security_rule" {
    for_each = {
      for rule in var.nsg_rules : rule.name => rule
    }

    content {
      name      = security_rule.value.name
      priority  = security_rule.value.priority
      direction = security_rule.value.direction
      access    = security_rule.value.access
      protocol  = security_rule.value.protocol

      source_port_range       = security_rule.value.source_port_range
      source_port_ranges      = security_rule.value.source_port_ranges
      source_address_prefix   = security_rule.value.source_address_prefix
      source_address_prefixes = security_rule.value.source_address_prefixes

      destination_port_range       = security_rule.value.destination_port_range
      destination_port_ranges      = security_rule.value.destination_port_ranges
      destination_address_prefix   = security_rule.value.destination_address_prefix
      destination_address_prefixes = security_rule.value.destination_address_prefixes

      source_application_security_group_ids = anytrue([
        length(security_rule.value.source_address_prefix) > 0,
        length(security_rule.value.source_address_prefixes) > 0,
      ]) ? [] : [azurerm_application_security_group.MAIN.id]

      destination_application_security_group_ids = anytrue([
        length(security_rule.value.destination_address_prefix) > 0,
        length(security_rule.value.destination_address_prefixes) > 0,
      ]) ? [] : [azurerm_application_security_group.MAIN.id]
    }
  }

  tags = var.tags
}

//////////////////////////////////
// Load Balancer | Internal
//////////////////////////////////

resource "azurerm_lb" "INTERNAL" {
  count = var.features.create_lb_internal ? 1 : 0

  name = join("-", [var.prefix, "lb", "internal"])
  sku  = "Basic"

  frontend_ip_configuration {
    name      = join("-", [local.frontend_ip_configuration_name, "internal"])
    subnet_id = data.azurerm_subnet.MAIN.id
  }
  location            = data.azurerm_resource_group.MAIN.location
  resource_group_name = data.azurerm_resource_group.MAIN.name
  tags                = var.tags
}

resource "azurerm_lb_backend_address_pool" "INTERNAL" {
  count = var.features.create_lb_internal ? 1 : 0

  name            = join("-", [local.backend_address_pool_name, "internal"])
  loadbalancer_id = one(azurerm_lb.INTERNAL.*.id)
}

resource "azurerm_lb_probe" "INTERNAL" {
  for_each = {
    for rule in var.lb_rules : rule.name => rule
    if alltrue([
      var.features.create_lb_internal,
      rule.internal,
      rule.number_of_probes > 0,
    ])
  }

  name                = each.value.name
  number_of_probes    = each.value.number_of_probes
  port                = try(each.value.probe_port > 0, each.value.backend_port)
  protocol            = try(length(each.value.probe_protocol) > 0, each.value.protocol)
  request_path        = each.value.probe_request_path
  interval_in_seconds = each.value.probe_interval

  loadbalancer_id = one(azurerm_lb.INTERNAL.*.id)
}

resource "azurerm_lb_rule" "INTERNAL" {
  for_each = {
    for rule in var.lb_rules : rule.name => rule
    if alltrue([
      var.features.create_lb_internal,
      rule.internal,
    ])
  }

  name              = each.value.name
  protocol          = each.value.protocol
  frontend_port     = each.value.frontend_port
  backend_port      = each.value.backend_port
  load_distribution = each.value.load_distribution

  probe_id                       = try(azurerm_lb_probe.INTERNAL[each.key].id, null)
  frontend_ip_configuration_name = join("-", [local.frontend_ip_configuration_name, "internal"])
  loadbalancer_id                = one(azurerm_lb.INTERNAL.*.id)
}

resource "azurerm_lb_nat_pool" "INTERNAL" {
  for_each = {
    for pool in var.nat_pools : pool.name => pool
    if alltrue([
      var.features.create_lb_internal,
      pool.internal,
    ])
  }

  name                = each.value.name
  protocol            = each.value.protocol
  frontend_port_start = each.value.frontend_port_start
  frontend_port_end   = each.value.frontend_port_end
  backend_port        = each.value.backend_port
  
  frontend_ip_configuration_name = join("-", [local.frontend_ip_configuration_name, "internal"])
  loadbalancer_id                = one(azurerm_lb.INTERNAL.*.id)
  resource_group_name            = data.azurerm_resource_group.MAIN.name
}

//////////////////////////////////
// Load Balancer | Public
//////////////////////////////////

resource "azurerm_public_ip" "PUBLIC" {
  count = var.features.create_lb_public ? 1 : 0

  name              = join("-", [var.prefix, "pip"])
  allocation_method = "Static"
  sku               = "Basic"

  resource_group_name = data.azurerm_resource_group.MAIN.name
  location            = data.azurerm_resource_group.MAIN.location
  tags                = var.tags
}

resource "azurerm_lb" "PUBLIC" {
  count = var.features.create_lb_public ? 1 : 0

  name = join("-", [var.prefix, "lb", "public"])
  sku  = "Basic"

  frontend_ip_configuration {
    name                 = join("-", [local.frontend_ip_configuration_name, "public"])
    public_ip_address_id = one(azurerm_public_ip.PUBLIC.*.id)
  }

  location            = data.azurerm_resource_group.MAIN.location
  resource_group_name = data.azurerm_resource_group.MAIN.name
  tags                = var.tags
}

resource "azurerm_lb_backend_address_pool" "PUBLIC" {
  count = var.features.create_lb_public ? 1 : 0

  name            = join("-", [local.backend_address_pool_name, "public"])
  loadbalancer_id = one(azurerm_lb.PUBLIC.*.id)
}

resource "azurerm_lb_probe" "PUBLIC" {
  for_each = {
    for rule in var.lb_rules : rule.name => rule
    if alltrue([
      var.features.create_lb_public,
      rule.public,
      rule.number_of_probes > 0,
    ])
  }

  name                = each.value.name
  number_of_probes    = each.value.number_of_probes
  port                = try(each.value.probe_port > 0, each.value.backend_port)
  protocol            = try(length(each.value.probe_protocol) > 0, each.value.protocol)
  request_path        = each.value.probe_request_path
  interval_in_seconds = each.value.probe_interval

  loadbalancer_id = one(azurerm_lb.PUBLIC.*.id)
}

resource "azurerm_lb_rule" "PUBLIC" {
  for_each = {
    for rule in var.lb_rules : rule.name => rule
    if alltrue([
      var.features.create_lb_public,
      rule.public,
    ])
  }

  name              = each.value.name
  protocol          = each.value.protocol
  frontend_port     = each.value.frontend_port
  backend_port      = each.value.backend_port
  load_distribution = each.value.load_distribution

  probe_id                       = try(azurerm_lb_probe.PUBLIC[each.key].id, null)
  frontend_ip_configuration_name = join("-", [local.frontend_ip_configuration_name, "public"])
  loadbalancer_id                = one(azurerm_lb.PUBLIC.*.id)
}

resource "azurerm_lb_nat_pool" "PUBLIC" {
  for_each = {
    for pool in var.nat_pools : pool.name => pool
    if alltrue([
      var.features.create_lb_public,
      pool.public,
    ])
  }

  name                = each.value.name
  protocol            = each.value.protocol
  frontend_port_start = each.value.frontend_port_start
  frontend_port_end   = each.value.frontend_port_end
  backend_port        = each.value.backend_port
  
  frontend_ip_configuration_name = join("-", [local.frontend_ip_configuration_name, "public"])
  loadbalancer_id                = one(azurerm_lb.PUBLIC.*.id)
  resource_group_name            = data.azurerm_resource_group.MAIN.name
}

//////////////////////////////////
// Virtual Machine Scale-Set
//////////////////////////////////

resource "azurerm_linux_virtual_machine_scale_set" "MAIN" {
  count = alltrue([
    var.features.create_vmss,
    upper(var.vmss.os) == "LINUX",
  ]) ? 1 : 0
  
  name                 = var.prefix
  computer_name_prefix = var.vmss.hostname
  sku                  = var.vmss.sku
  instances            = var.vmss.instances
  admin_username       = var.vmss.admin_username
  admin_password       = var.vmss.admin_password
  priority             = var.vmss.priority
  eviction_policy      = var.vmss.eviction_policy
  max_bid_price        = var.vmss.max_bid_price
  overprovision        = var.vmss.overprovision

  disable_password_authentication = length(var.vmss.admin_password) > 0 ? false : true

  source_image_reference {
    publisher = var.vmss.image_publisher
    offer     = var.vmss.image_offer
    sku       = var.vmss.image_sku
    version   = var.vmss.image_version
  }

  os_disk {
    storage_account_type = "Standard_LRS"
    caching              = "ReadWrite"
  }

  network_interface {
    name    = local.vmss_nic_name
    primary = true
    network_security_group_id = one(azurerm_network_security_group.MAIN.*.id)

    ip_configuration {
      primary   = true
      name      = "internal"
      subnet_id = data.azurerm_subnet.MAIN.id

      application_security_group_ids = flatten([
        azurerm_application_security_group.MAIN.id
      ])

      load_balancer_backend_address_pool_ids = flatten([
        [for bepool in azurerm_lb_backend_address_pool.INTERNAL: bepool.id],
        [for bepool in azurerm_lb_backend_address_pool.PUBLIC: bepool.id],
      ])

      load_balancer_inbound_nat_rules_ids = flatten([
        [for natpool in azurerm_lb_nat_pool.INTERNAL: natpool.id ],
        [for natpool in azurerm_lb_nat_pool.PUBLIC: natpool.id ],
      ])
    }
  }

  resource_group_name = data.azurerm_resource_group.MAIN.name
  location            = data.azurerm_resource_group.MAIN.location

  lifecycle {
    replace_triggered_by = []
  }
}
