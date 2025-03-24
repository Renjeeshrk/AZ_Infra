terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "4.23.0"
    }
  }
}

provider "azurerm" {
  features {}
   subscription_id = "<Subscription ID>"
}

# Resource Group
resource "azurerm_resource_group" "rg_infrabeast_eastus" {
  name     = "rg_infrabeast_eastus_02"
  location = "East US"
}

# Virtual Network
resource "azurerm_virtual_network" "az_vnet_pro_eastus_01" {
  name                = "az_vnet_pro_eastus_01"
  location            = azurerm_resource_group.rg_infrabeast_eastus.location
  resource_group_name = azurerm_resource_group.rg_infrabeast_eastus.name
  address_space       = ["10.0.0.0/19"]

  tags = {
    environment = "Production"
  }
}

# Web Subnet
resource "azurerm_subnet" "az_subnet_prod_web_01" {
  name                 = "az_subnet_prod_web-01"
  resource_group_name  = azurerm_resource_group.rg_infrabeast_eastus.name
  virtual_network_name = azurerm_virtual_network.az_vnet_pro_eastus_01.name
  address_prefixes     = ["10.0.0.0/23"]
}

# App Gateway Subnet
resource "azurerm_subnet" "pro_gw01_subnet_data" {
  name                 = "pro_gw01"
  resource_group_name  = azurerm_resource_group.rg_infrabeast_eastus.name
  virtual_network_name = azurerm_virtual_network.az_vnet_pro_eastus_01.name
  address_prefixes     = ["10.0.2.0/23"]
}

# Public IP for Management VM
resource "azurerm_public_ip" "mgmt_vm_public_ip" {
  name                = "mgmt-vm-public-ip"
  location            = azurerm_resource_group.rg_infrabeast_eastus.location
  resource_group_name = azurerm_resource_group.rg_infrabeast_eastus.name
  allocation_method   = "Static"  
  sku                 = "Standard"  
}

# NIC for Management VM
resource "azurerm_network_interface" "mgmt_vm_nic" {
  name                = "mgmt-vm-nic"
  location            = azurerm_resource_group.rg_infrabeast_eastus.location
  resource_group_name = azurerm_resource_group.rg_infrabeast_eastus.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.az_subnet_prod_web_01.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.mgmt_vm_public_ip.id  
  }
}

# NSG for Management VM
resource "azurerm_network_security_group" "mgmt_nsg" {
  name                = "mgmt-nsg01"
  location            = azurerm_resource_group.rg_infrabeast_eastus.location
  resource_group_name = azurerm_resource_group.rg_infrabeast_eastus.name

  security_rule {
    name                       = "RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "*"
    source_port_range          = "*"
    destination_port_range     = "3389"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
  security_rule {
    name                       = "web"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "80"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# NSG Association
resource "azurerm_network_interface_security_group_association" "mgmt_nsg_assoc" {
  network_interface_id      = azurerm_network_interface.mgmt_vm_nic.id
  network_security_group_id = azurerm_network_security_group.mgmt_nsg.id
}

# Storage Account for Boot Diagnostics
resource "azurerm_storage_account" "my_storage_account" {
  name                     = "diagacc01rktesting"
  location                 = azurerm_resource_group.rg_infrabeast_eastus.location
  resource_group_name      = azurerm_resource_group.rg_infrabeast_eastus.name
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Management VM
resource "azurerm_windows_virtual_machine" "mgmt_vm" {
  name                  = "mgmt-vm"
  admin_username        = "azureuser"
  admin_password        = "XXXXXX" # Local admin password 
  location              = azurerm_resource_group.rg_infrabeast_eastus.location
  resource_group_name   = azurerm_resource_group.rg_infrabeast_eastus.name
  network_interface_ids = [azurerm_network_interface.mgmt_vm_nic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }
}

# NIC for Home Server
resource "azurerm_network_interface" "web_vm_nic" {
  name                = "web-nic"
  location            = azurerm_resource_group.rg_infrabeast_eastus.location
  resource_group_name = azurerm_resource_group.rg_infrabeast_eastus.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.az_subnet_prod_web_01.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Home Server VM
resource "azurerm_windows_virtual_machine" "az-srv-home-01" {
  name                  = "az-srv-home-01"
  admin_username        = "azureuser"
  admin_password        = "XXXXXX" # Local admin password 
  location              = azurerm_resource_group.rg_infrabeast_eastus.location
  resource_group_name   = azurerm_resource_group.rg_infrabeast_eastus.name
  network_interface_ids = [azurerm_network_interface.web_vm_nic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "myOsDisk1"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }
}

# Install IIS on Home Server
resource "azurerm_virtual_machine_extension" "az_srv_home_01_iis" {
  name                       = "az-srv-home-01-iis"
  virtual_machine_id         = azurerm_windows_virtual_machine.az-srv-home-01.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.8"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -IncludeManagementTools"
    }
  SETTINGS
}

# NIC for Image Server
resource "azurerm_network_interface" "srv_img_01_nic" {
  name                = "srv-img-01-nic"
  location            = azurerm_resource_group.rg_infrabeast_eastus.location
  resource_group_name = azurerm_resource_group.rg_infrabeast_eastus.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.az_subnet_prod_web_01.id
    private_ip_address_allocation = "Dynamic"
  }
}

# Image Server VM
resource "azurerm_windows_virtual_machine" "az-srv-img-01" {
  name                  = "az-srv-img-01"
  admin_username        = "azureuser"
  admin_password        = "XXXXXX" # Local admin password 
  location              = azurerm_resource_group.rg_infrabeast_eastus.location
  resource_group_name   = azurerm_resource_group.rg_infrabeast_eastus.name
  network_interface_ids = [azurerm_network_interface.srv_img_01_nic.id]
  size                  = "Standard_DS1_v2"

  os_disk {
    name                 = "myOsDisk2"
    caching              = "ReadWrite"
    storage_account_type = "Premium_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2022-datacenter-azure-edition"
    version   = "latest"
  }

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }
}

# Install IIS on Image Server
resource "azurerm_virtual_machine_extension" "az_srv_img_01_iis" {
  name                       = "az-srv-img-01-iis"
  virtual_machine_id         = azurerm_windows_virtual_machine.az-srv-img-01.id
  publisher                  = "Microsoft.Compute"
  type                       = "CustomScriptExtension"
  type_handler_version       = "1.8"
  auto_upgrade_minor_version = true

  settings = <<SETTINGS
    {
      "commandToExecute": "powershell -ExecutionPolicy Unrestricted Install-WindowsFeature -Name Web-Server -IncludeAllSubFeature -IncludeManagementTools"
    }
  SETTINGS
}


//// Deploying Azure Application gateway 

// Create public IP for Gateway

resource "azurerm_public_ip" "az-apgw01-pip" {
  name                = "az-apgw01-pip01"
  location              = azurerm_resource_group.rg_infrabeast_eastus.location
  resource_group_name   = azurerm_resource_group.rg_infrabeast_eastus.name
  allocation_method   = "Static"
}


locals {
  backend_address_pool_home_name  = "home-backend-pool"
  backend_address_pool_image_name = "image-backend-pool"
  frontend_port_name             = "appGwFrontendPort"
  frontend_ip_configuration_name = "appGwFrontendIP"
  http_setting_name              = "http-setting"
  listener_name                  = "http-listener"
  url_path_map_name              = "url-path-map"
  routing_rule_name              = "path-routing-rule"
}

resource "azurerm_application_gateway" "aw-apgw-01" {
  name                = "aw-apgw-01"
  location            = azurerm_resource_group.rg_infrabeast_eastus.location
  resource_group_name = azurerm_resource_group.rg_infrabeast_eastus.name

  sku {
    name     = "Standard_v2"
    tier     = "Standard_v2"
    capacity = 2
  }

  gateway_ip_configuration {
    name      = "AppGatewayIPConfig"
    subnet_id = azurerm_subnet.pro_gw01_subnet_data.id
  }

  frontend_ip_configuration {
    name                 = local.frontend_ip_configuration_name
    public_ip_address_id = azurerm_public_ip.az-apgw01-pip.id
  }

  frontend_port {
    name = local.frontend_port_name
    port = 80
  }

  backend_address_pool {
  name         = local.backend_address_pool_home_name
  ip_addresses = [azurerm_network_interface.web_vm_nic.private_ip_address]

}

  backend_address_pool {
  name         = local.backend_address_pool_image_name
  ip_addresses = [azurerm_network_interface.srv_img_01_nic.private_ip_address]

}

  backend_http_settings {
    name                  = local.http_setting_name
    cookie_based_affinity = "Disabled"
    port                  = 80
    protocol              = "Http"
    request_timeout       = 60
  }

  http_listener {
    name                           = local.listener_name
    frontend_ip_configuration_name = local.frontend_ip_configuration_name
    frontend_port_name             = local.frontend_port_name
    protocol                       = "Http"
  }

  url_path_map {
    name                               = local.url_path_map_name
    default_backend_address_pool_name  = local.backend_address_pool_home_name
    default_backend_http_settings_name = local.http_setting_name

    path_rule {
      name                       = "images-path"
      paths                      = ["/images/*"]
      backend_address_pool_name  = local.backend_address_pool_image_name
      backend_http_settings_name = local.http_setting_name
    }
  }

  request_routing_rule {
    name              = local.routing_rule_name
    rule_type         = "PathBasedRouting"
    http_listener_name = local.listener_name
    url_path_map_name  = local.url_path_map_name
    priority           = 100
  }
}
