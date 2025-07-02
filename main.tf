data "azurerm_resource_group" "test" {
  name     = "rg_ward_directory_az_104"
}

# Create virtual network
resource "azurerm_virtual_network" "my_terraform_network" {
  name                = "myVnet"
  address_space       = ["10.0.0.0/16"]
  location            = "${data.azurerm_resource_group.test.location}"
  resource_group_name = "${data.azurerm_resource_group.test.name}"
}

# Create 5 subnets: Stake President, Bishopric, EQP, RSP, and member

# Create subnet
resource "azurerm_subnet" "ward_directory_az_104_subnet_sp" {
  name                 = "mySubnetStakePresident"
  resource_group_name  = "${data.azurerm_resource_group.test.name}"
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.1.0/24"]
}

# Create subnet
resource "azurerm_subnet" "ward_directory_az_104_subnet_bishop" {
  name                 = "mySubnetBishopric"
  resource_group_name  = "${data.azurerm_resource_group.test.name}"
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.2.0/24"]
}

# Create subnet
resource "azurerm_subnet" "ward_directory_az_104_subnet_eqp" {
  name                 = "mySubnetEQP"
  resource_group_name  = "${data.azurerm_resource_group.test.name}"
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.3.0/24"]
}

# Create subnet
resource "azurerm_subnet" "ward_directory_az_104_subnet_rsp" {
  name                 = "mySubnetRSP"
  resource_group_name  = "${data.azurerm_resource_group.test.name}"
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.4.0/24"]
}

# Create subnet
resource "azurerm_subnet" "ward_directory_az_104_subnet_member" {
  name                 = "mySubnetMember"
  resource_group_name  = "${data.azurerm_resource_group.test.name}"
  virtual_network_name = azurerm_virtual_network.my_terraform_network.name
  address_prefixes     = ["10.0.5.0/24"]
}

# Create 2 public IPs (one for admin and one for member)
resource "azurerm_public_ip" "my_terraform_public_ip_admin" {
  name                = "myPublicIPAdmin"
  location            = "${data.azurerm_resource_group.test.location}"
  resource_group_name = "${data.azurerm_resource_group.test.name}"
  allocation_method   = "Dynamic"
}

resource "azurerm_public_ip" "my_terraform_public_ip_member" {
  name                = "myPublicIPMember"
  location            = "${data.azurerm_resource_group.test.location}"
  resource_group_name = "${data.azurerm_resource_group.test.name}"
  allocation_method   = "Static"
}

# Create Network Security Group and rule
resource "azurerm_network_security_group" "ward_directory_nsg_az_104" {
  name                = "myNetworkSecurityGroupWardDirectory"
  location            = "${data.azurerm_resource_group.test.location}"
  resource_group_name = "${data.azurerm_resource_group.test.name}"

  security_rule {
    name                       = "SSH"
    priority                   = 1001
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  security_rule {
    name                       = "RDP"
    priority                   = 1000
    direction                  = "Inbound"
    access                     = "Deny"
    protocol                   = "Udp"
    source_port_range          = "*"
    destination_port_range     = "64"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }
}

# Create network interface
resource "azurerm_network_interface" "ward_directory_nic_az_104" {
  name                = "myNIC"
  location            = "${data.azurerm_resource_group.test.location}"
  resource_group_name = "${data.azurerm_resource_group.test.name}"

  ip_configuration {
    name                          = "my_nic_configuration"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Dynamic"
    public_ip_address_id          = azurerm_public_ip.my_terraform_public_ip.id
  }

  # Backup configuration just in case.
  ip_configuration {
    name                          = "my_nic_configuration_backup"
    subnet_id                     = azurerm_subnet.my_terraform_subnet.id
    private_ip_address_allocation = "Static"
    public_ip_address_id          = azurerm_public_ip.my_terraform_public_ip.id
  }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
  network_interface_id      = azurerm_network_interface.ward_directory_nic_az_104.id
  network_security_group_id = azurerm_network_security_group.ward_directory_nsg_az_104.id
}

# Generate random text for a unique storage account name
resource "random_id" "random_id" {
  keepers = {
    # Generate a new ID only when a new resource group is defined
    resource_group = "${data.azurerm_resource_group.test.name}"
  }

  byte_length = 16
}

# Create storage account for boot diagnostics
resource "azurerm_storage_account" "my_storage_account" {
  name                     = "diag${random_id.random_id.hex}"
  location                 = "${data.azurerm_resource_group.test.location}"
  resource_group_name      = "${data.azurerm_resource_group.test.name}"
  account_tier             = "Standard"
  account_replication_type = "LRS"
}

# Create (and display) an SSH key
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits  = 4096
}

# Create virtual machine
resource "azurerm_linux_virtual_machine" "my_terraform_vm" {
  name                  = "myVM"
  location              = "${data.azurerm_resource_group.test.location}"
  resource_group_name   = "${data.azurerm_resource_group.test.name}"
  network_interface_ids = [azurerm_network_interface.my_terraform_nic.id]
  size                  = "Standard_B2s"

  os_disk {
    name                 = "myOsDisk"
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts-gen2"
    version   = "latest"
  }

  computer_name                   = "myvm"
  admin_username                  = "azureuser"
  disable_password_authentication = true

  admin_ssh_key {
  username   = "azureuser"
  public_key = azapi_resource_action.ssh_public_key_gen.output.publicKey
}

  boot_diagnostics {
    storage_account_uri = azurerm_storage_account.my_storage_account.primary_blob_endpoint
  }
}
