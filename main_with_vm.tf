# AZ 104 Ward Directory Terraform file with VM.

terraform {
  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "<= 3.0"
    }
  }
}

provider "azurerm" {
  features {}
  skip_provider_registration = true
}

locals {
  resource_group = "ward_az104_directory_rg"  # Replace with your resource group name
  location       = "eastus"               # Update with your resource group's location
}

data "azurerm_resource_group" "existing_rg" {
  name = local.resource_group
}

resource "az104_ward_directory_vnet" "app_network" {
  name                = "app-network"
  location            = data.azurerm_resource_group.existing_rg.location
  resource_group_name = data.azurerm_resource_group.existing_rg.name
  address_space       = ["10.0.0.0/16"]
}

# Subnets for each Ward directory portion
resource "bishopric" "SubnetA" {
  name                 = "SubnetA"
  resource_group_name  = data.azurerm_resource_group.existing_rg.name
  virtual_network_name = azurerm_virtual_network.app_network.name
  address_prefixes     = ["10.0.0.0/24"]
}

resource "rsp_eqp" "SubnetB" {
  name                 = "SubnetB"
  resource_group_name  = data.azurerm_resource_group.existing_rg.name
  virtual_network_name = azurerm_virtual_network.app_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

resource "member" "SubnetC" {
  name                 = "SubnetC"
  resource_group_name  = data.azurerm_resource_group.existing_rg.name
  virtual_network_name = azurerm_virtual_network.app_network.name
  address_prefixes     = ["10.1.0.0/24"]
}

resource "azurerm_network_interface" "app_interface" {
  name                = "app-interface"
  location            = data.azurerm_resource_group.existing_rg.location
  resource_group_name = data.azurerm_resource_group.existing_rg.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.SubnetA.id
    private_ip_address_allocation = "Dynamic"
  }
}

resource "azurerm_windows_virtual_machine" "app_vm" {
  name                = "appvm"
  resource_group_name = data.azurerm_resource_group.existing_rg.name
  location            = data.azurerm_resource_group.existing_rg.location
  size                = "Standard_B2s"
  admin_username      = "demouser123"
  admin_password      = "Azure@AZ104WardDirectory"
  network_interface_ids = [
    azurerm_network_interface.app_interface.id
  ]

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "MicrosoftWindowsServer"
    offer     = "WindowsServer"
    sku       = "2019-Datacenter"
    version   = "latest"
  }
}

resource "azurerm_monitor_action_group" "email_alert" {
  name                = "email-alert"
  resource_group_name = data.azurerm_resource_group.existing_rg.name
  short_name          = "email-alert"

  email_receiver {
    name                    = "sendtoAdmin"
    email_address           = "jasonlu968@gmail.com"  # Update with your email
    use_common_alert_schema = true
  }
}

resource "azurerm_monitor_metric_alert" "Network_Threshold_alert" {
  name                = "Network-Threshold-alert"
  resource_group_name = data.azurerm_resource_group.existing_rg.name
  scopes              = [azurerm_windows_virtual_machine.app_vm.id]
  description         = "The alert will be sent if NetworkByte > 70"

  criteria {
    metric_namespace = "Microsoft.Compute/virtualMachines"
    metric_name      = "Network Out Total"
    aggregation      = "Total"
    operator         = "GreaterThan"
    threshold        = 70
  }

  action {
    action_group_id = azurerm_monitor_action_group.email_alert.id
  }
}
