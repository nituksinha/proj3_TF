resource "azurerm_resource_group" "mytfgroup" {
  name     = "mytfgroup"
  location = "eastus"

  tags = {
    environment = "Terraform Demo"
  }
}
resource "azurerm_virtual_network" "mytfnetwork" {
    name                = "mytfvnet"
    address_space       = ["10.0.0.0/16"]
    location            = "eastus"
    resource_group_name = azurerm_resource_group.mytfgroup.name

    tags = {
        environment = "Terraform Demo"
    }
}
resource "azurerm_subnet" "mytfsubnet" {
    name = "mysubnet"
    resource_group_name  = azurerm_resource_group.mytfgroup.name
    virtual_network_name = azurerm_virtual_network.mytfnetwork.name
    address_prefix     = "10.0.2.0/24"
}
resource "azurerm_public_ip" "mytfpublicip" {
    name                         = "myPublicIP"
    location                     = "eastus"
    resource_group_name          = azurerm_resource_group.mytfgroup.name
    allocation_method            = "Dynamic"

    tags = {
        environment = "Terraform Demo"
    }
}
resource "azurerm_network_security_group" "mytfnsg" {
    name                = "mytfnsgroup"
    location            = "eastus"
    resource_group_name = azurerm_resource_group.mytfgroup.name
    
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

    tags = {
        environment = "Terraform Demo"
    }
}
resource "azurerm_network_interface" "mytfnic" {
    name                        = "myNIC"
    location                    = "eastus"
    resource_group_name         = azurerm_resource_group.mytfgroup.name

    ip_configuration {
        name                          = "myNicConfiguration"
        subnet_id                     = azurerm_subnet.mytfsubnet.id
        private_ip_address_allocation = "Dynamic"
        public_ip_address_id          = azurerm_public_ip.mytfpublicip.id
    }
    tags = {
        environment = "Terraform Demo"
    }
}

# Connect the security group to the network interface
resource "azurerm_network_interface_security_group_association" "example" {
    network_interface_id      = azurerm_network_interface.mytfnic.id
    network_security_group_id = azurerm_network_security_group.mytfnsg.id
}
# Generate random text for a unique storage account name
resource "random_id" "randomId" {
    keepers = {
        # Generate a new ID only when a new resource group is defined
        resource_group = azurerm_resource_group.mytfgroup.name
    }
    
    byte_length = 8
}
# Create storage account for boot diagnostics
resource "azurerm_storage_account" "mytfstorageaccount" {
    name                        = "diag${random_id.randomId.hex}"
    resource_group_name         = azurerm_resource_group.mytfgroup.name
    location                    = "eastus"
    account_tier                = "Standard"
    account_replication_type    = "LRS"

    tags = {
        environment = "Terraform Demo"
    }
}
resource "tls_private_key" "example_ssh" {
  algorithm = "RSA"
  rsa_bits = 4096
}

output "tls_private_key" { value = "tls_private_key.example_ssh.private_key_pem" }

resource "azurerm_linux_virtual_machine" "mynewtfvm" {
    name                  = "mytfVM"
    location              = "eastus"
    resource_group_name   = azurerm_resource_group.mytfgroup.name
    network_interface_ids = [azurerm_network_interface.mytfnic.id]
    size                  = "Standard_DS1_v2"

    os_disk {
        name              = "myOsDisk"
        caching           = "ReadWrite"
        storage_account_type = "Premium_LRS"
    }

    source_image_reference {
        publisher = "Canonical"
        offer     = "UbuntuServer"
        sku       = "16.04.0-LTS"
        version   = "latest"
    }

    computer_name  = "mynewtfvm"
    admin_username = "azureuser"
    disable_password_authentication = true
        
    admin_ssh_key {
        username       = "azureuser"
        public_key     = tls_private_key.example_ssh.public_key_openssh
    }

    boot_diagnostics {
        storage_account_uri = azurerm_storage_account.mytfstorageaccount.primary_blob_endpoint
    }

    tags = {
        environment = "Terraform Demo"
    }
}
