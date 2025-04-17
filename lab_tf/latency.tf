provider "azurerm" {
  features {}
  subscription_id = var.subscription_id
  client_id       = var.client_id
  client_secret   = var.client_secret
  tenant_id       = var.tenant_id
}

# Bootstrap scripts for VMs
locals {
  server_bootstrap_script = <<-EOT
  #!/bin/bash
  apt-get update
  apt-get upgrade -y
  su - ${var.admin_username} -c "git clone https://github.com/simonpainter/echo_test.git"
  # Server-specific setup
  # Run the echo server setup script
  cp /home/${var.admin_username}/echo_test/server/setup-echo-server.sh /tmp/
  chmod +x /tmp/setup-echo-server.sh
  /tmp/setup-echo-server.sh
  EOT

  client_bootstrap_script = <<-EOT
  #!/bin/bash
  apt-get update
  apt-get upgrade -y
  su - ${var.admin_username} -c "git clone https://github.com/simonpainter/echo_test.git"
  DEBIAN_FRONTEND=noninteractive apt-get upgrade -y
  # Client-specific setup
  apt-get install -y python-is-python3
  
  EOT
}

# Variables
variable "client_secret" {
  description = "Client Secret"
}

variable "client_id" {
  description = "Client ID"
}

variable "tenant_id" {
  description = "Tenant ID"
}

variable "subscription_id" {
  description = "Subscription ID"
}

variable "primary_region" {
  description = "Primary Azure region for resources (default: West US)"
  type        = string
  default     = "West US"
}

variable "secondary_region" {
  description = "Secondary Azure region for resources (default: UK South)"
  type        = string
  default     = "UK South"
}

variable "admin_username" {
  description = "Admin username for VMs"
  default     = "azureuser"
}

variable "admin_password" {
  description = "Admin password for VMs"
  sensitive   = true
}

# Resource Group - Primary Region
resource "azurerm_resource_group" "primary_rg" {
  name     = "latency-test-${lower(replace(var.primary_region, " ", "-"))}"
  location = var.primary_region
}

# Resource Group - Secondary Region
resource "azurerm_resource_group" "secondary_rg" {
  name     = "latency-test-${lower(replace(var.secondary_region, " ", "-"))}"
  location = var.secondary_region
}

# Virtual Network - Primary Region
resource "azurerm_virtual_network" "primary_vnet" {
  name                = "${lower(replace(var.primary_region, " ", "-"))}-vnet"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.primary_rg.location
  resource_group_name = azurerm_resource_group.primary_rg.name
}

# Subnet - Primary Region
resource "azurerm_subnet" "primary_subnet" {
  name                 = "${lower(replace(var.primary_region, " ", "-"))}-subnet"
  resource_group_name  = azurerm_resource_group.primary_rg.name
  virtual_network_name = azurerm_virtual_network.primary_vnet.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Load Balancer Subnet - Primary Region
resource "azurerm_subnet" "primary_lb_subnet" {
  name                 = "${lower(replace(var.primary_region, " ", "-"))}-lb-subnet"
  resource_group_name  = azurerm_resource_group.primary_rg.name
  virtual_network_name = azurerm_virtual_network.primary_vnet.name
  address_prefixes     = ["10.0.2.0/24"]
  private_link_service_network_policies_enabled = false
}

# Virtual Network - Secondary Region
resource "azurerm_virtual_network" "secondary_vnet" {
  name                = "${lower(replace(var.secondary_region, " ", "-"))}-vnet"
  address_space       = ["10.1.0.0/16"]
  location            = azurerm_resource_group.secondary_rg.location
  resource_group_name = azurerm_resource_group.secondary_rg.name
}

# Subnet - Secondary Region
resource "azurerm_subnet" "secondary_subnet" {
  name                 = "${lower(replace(var.secondary_region, " ", "-"))}-subnet"
  resource_group_name  = azurerm_resource_group.secondary_rg.name
  virtual_network_name = azurerm_virtual_network.secondary_vnet.name
  address_prefixes     = ["10.1.1.0/24"]
}

# Private Link Subnet - Secondary Region
resource "azurerm_subnet" "secondary_pl_subnet" {
  name                = "${lower(replace(var.secondary_region, " ", "-"))}-pl-subnet"
  resource_group_name = azurerm_resource_group.secondary_rg.name
  virtual_network_name = azurerm_virtual_network.secondary_vnet.name
  address_prefixes    = ["10.1.2.0/24"]
}

# VNET Peering - Primary to Secondary
resource "azurerm_virtual_network_peering" "primary_to_secondary" {
  name                         = "primary-to-secondary"
  resource_group_name          = azurerm_resource_group.primary_rg.name
  virtual_network_name         = azurerm_virtual_network.primary_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.secondary_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# VNET Peering - Secondary to Primary
resource "azurerm_virtual_network_peering" "secondary_to_primary" {
  name                         = "secondary-to-primary"
  resource_group_name          = azurerm_resource_group.secondary_rg.name
  virtual_network_name         = azurerm_virtual_network.secondary_vnet.name
  remote_virtual_network_id    = azurerm_virtual_network.primary_vnet.id
  allow_virtual_network_access = true
  allow_forwarded_traffic      = true
  allow_gateway_transit        = false
  use_remote_gateways          = false
}

# Network Security Group - Primary Region
resource "azurerm_network_security_group" "primary_nsg" {
  name                = "${lower(replace(var.primary_region, " ", "-"))}-nsg"
  location            = azurerm_resource_group.primary_rg.location
  resource_group_name = azurerm_resource_group.primary_rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "AllowTCP7"
    priority                   = 110
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "7"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Network Security Group - Secondary Region
resource "azurerm_network_security_group" "secondary_nsg" {
  name                = "${lower(replace(var.secondary_region, " ", "-"))}-nsg"
  location            = azurerm_resource_group.secondary_rg.location
  resource_group_name = azurerm_resource_group.secondary_rg.name

  security_rule {
    name                       = "AllowSSH"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Private Load Balancer - Primary Region
resource "azurerm_lb" "primary_lb" {
  name                = "${lower(replace(var.primary_region, " ", "-"))}-lb"
  location            = azurerm_resource_group.primary_rg.location
  resource_group_name = azurerm_resource_group.primary_rg.name
  sku                 = "Standard"

  frontend_ip_configuration {
    name                          = "frontend-ip"
    subnet_id                     = azurerm_subnet.primary_lb_subnet.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Backend Address Pool - Primary Region LB
resource "azurerm_lb_backend_address_pool" "primary_lb_backend" {
  loadbalancer_id = azurerm_lb.primary_lb.id
  name            = "BackendPool"
}

# Health Probe - Primary Region LB
resource "azurerm_lb_probe" "primary_lb_probe" {
  loadbalancer_id = azurerm_lb.primary_lb.id
  name            = "tcp-7-probe"
  port            = 7
  protocol        = "Tcp"
}

# Load Balancing Rule - Primary Region LB
resource "azurerm_lb_rule" "primary_lb_rule" {
  loadbalancer_id                = azurerm_lb.primary_lb.id
  name                           = "tcp-7-rule"
  protocol                       = "Tcp"
  frontend_port                  = 7
  backend_port                   = 7
  frontend_ip_configuration_name = "frontend-ip"
  backend_address_pool_ids       = [azurerm_lb_backend_address_pool.primary_lb_backend.id]
  probe_id                       = azurerm_lb_probe.primary_lb_probe.id
}

# Public IP for Primary Region VM
resource "azurerm_public_ip" "primary_vm_pip" {
  name                = "${lower(replace(var.primary_region, " ", "-"))}-vm-pip"
  location            = azurerm_resource_group.primary_rg.location
  resource_group_name = azurerm_resource_group.primary_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Interface - Primary Region VM
resource "azurerm_network_interface" "primary_vm_nic" {
  name                = "${lower(replace(var.primary_region, " ", "-"))}-vm-nic"
  location            = azurerm_resource_group.primary_rg.location
  resource_group_name = azurerm_resource_group.primary_rg.name
  accelerated_networking_enabled  = true
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.primary_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.primary_vm_pip.id
  }
}

# Associate NSG to NIC - Primary Region
resource "azurerm_network_interface_security_group_association" "primary_nic_nsg" {
  network_interface_id      = azurerm_network_interface.primary_vm_nic.id
  network_security_group_id = azurerm_network_security_group.primary_nsg.id
}

# Backend Address Pool Association - Primary Region
resource "azurerm_network_interface_backend_address_pool_association" "primary_nic_lb" {
  network_interface_id    = azurerm_network_interface.primary_vm_nic.id
  ip_configuration_name   = "internal"
  backend_address_pool_id = azurerm_lb_backend_address_pool.primary_lb_backend.id
}

# Virtual Machine - Primary Region
resource "azurerm_linux_virtual_machine" "primary_vm" {
  name                = "${lower(replace(var.primary_region, " ", "-"))}-vm"
  resource_group_name = azurerm_resource_group.primary_rg.name
  location            = azurerm_resource_group.primary_rg.location
  size                = "Standard_B20ms"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  disable_password_authentication = false
  custom_data         = base64encode(local.server_bootstrap_script)
  
  network_interface_ids = [
    azurerm_network_interface.primary_vm_nic.id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}

# Public IPs for Secondary Region VMs
resource "azurerm_public_ip" "secondary_vm_pip" {
  count               = 3
  name                = "${lower(replace(var.secondary_region, " ", "-"))}-vm-${count.index + 1}-pip"
  location            = azurerm_resource_group.secondary_rg.location
  resource_group_name = azurerm_resource_group.secondary_rg.name
  allocation_method   = "Static"
  sku                 = "Standard"
}

# Network Interfaces - Secondary Region VMs
resource "azurerm_network_interface" "secondary_vm_nic" {
  count               = 3
  name                = "${lower(replace(var.secondary_region, " ", "-"))}-vm-${count.index + 1}-nic"
  location            = azurerm_resource_group.secondary_rg.location
  resource_group_name = azurerm_resource_group.secondary_rg.name
  accelerated_networking_enabled = true
  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.secondary_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.secondary_vm_pip[count.index].id
  }
}

# Associate NSG to NICs - Secondary Region
resource "azurerm_network_interface_security_group_association" "secondary_nic_nsg" {
  count                     = 3
  network_interface_id      = azurerm_network_interface.secondary_vm_nic[count.index].id
  network_security_group_id = azurerm_network_security_group.secondary_nsg.id
}

# Virtual Machines - Secondary Region
resource "azurerm_linux_virtual_machine" "secondary_vm" {
  count               = 3
  name                = "${lower(replace(var.secondary_region, " ", "-"))}-vm-${count.index + 1}"
  resource_group_name = azurerm_resource_group.secondary_rg.name
  location            = azurerm_resource_group.secondary_rg.location
  size                = "Standard_B20ms"
  admin_username      = var.admin_username
  admin_password      = var.admin_password
  disable_password_authentication = false
  zone                = 1  # Specify Availability Zone 1 for all Secondary Region VMs
  custom_data         = base64encode(local.client_bootstrap_script)

  network_interface_ids = [
    azurerm_network_interface.secondary_vm_nic[count.index].id,
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-focal"
    sku       = "20_04-lts"
    version   = "latest"
  }
}

# Private Link Service - Primary Region
resource "azurerm_private_link_service" "primary_pl_service" {
  name                = "${lower(replace(var.primary_region, " ", "-"))}-pl-service"
  location            = azurerm_resource_group.primary_rg.location
  resource_group_name = azurerm_resource_group.primary_rg.name

  nat_ip_configuration {
    name                       = "primary"
    private_ip_address_version = "IPv4"
    subnet_id                  = azurerm_subnet.primary_lb_subnet.id
    primary                    = true
  }

  load_balancer_frontend_ip_configuration_ids = [
    azurerm_lb.primary_lb.frontend_ip_configuration[0].id,
  ]
}

# Private Endpoint - Secondary Region
resource "azurerm_private_endpoint" "secondary_private_endpoint" {
  name                = "${lower(replace(var.secondary_region, " ", "-"))}-private-endpoint"
  location            = azurerm_resource_group.secondary_rg.location
  resource_group_name = azurerm_resource_group.secondary_rg.name
  subnet_id           = azurerm_subnet.secondary_pl_subnet.id

  private_service_connection {
    name                           = "secondary-to-primary-connection"
    private_connection_resource_id = azurerm_private_link_service.primary_pl_service.id
    is_manual_connection           = false
  }
}

# Outputs
output "primary_vm_public_ip" {
  description = "Public IP address of the VM in the primary region"
  value       = azurerm_public_ip.primary_vm_pip.ip_address
}

output "primary_vm_private_ip" {
  description = "Private IP address of the VM in the primary region"
  value       = azurerm_network_interface.primary_vm_nic.private_ip_address
}

output "primary_lb_private_ip" {
  description = "Private IP address of the load balancer in the primary region"
  value       = azurerm_lb.primary_lb.frontend_ip_configuration[0].private_ip_address
}

output "secondary_vm_public_ips" {
  description = "Public IP addresses of the VMs in the secondary region"
  value       = [for pip in azurerm_public_ip.secondary_vm_pip : pip.ip_address]
}

output "secondary_vm_private_ips" {
  description = "Private IP addresses of the VMs in the secondary region"
  value       = [for nic in azurerm_network_interface.secondary_vm_nic : nic.private_ip_address]
}

output "private_endpoint_ip" {
  description = "Private IP address of the private endpoint in the secondary region"
  value       = azurerm_private_endpoint.secondary_private_endpoint.private_service_connection[0].private_ip_address
}