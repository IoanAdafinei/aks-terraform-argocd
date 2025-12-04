resource "azurerm_resource_group" "main" {
  name     = "rg-${var.application_name}"
  location = var.primary_location

  tags = {
    Created_By = "Terraform"
  }
}

resource "azurerm_virtual_network" "main" {
  name                = "vnet-${var.application_name}"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  address_space       = ["10.0.10.0/24"]

  tags = {
    Created_By = "Terraform"
  }
}

resource "azurerm_subnet" "main" {
  name                 = "snet-default"
  resource_group_name  = azurerm_resource_group.main.name
  virtual_network_name = azurerm_virtual_network.main.name
  address_prefixes     = ["10.0.10.0/24"]
}

resource "azurerm_kubernetes_cluster" "aks" {
  name                = "aks-demo"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name
  dns_prefix          = "aksdemocluster"

  default_node_pool {
    name       = "nodepool1"
    node_count = 1
    vm_size    = "Standard_A2_v2"
  }

  identity {
    type = "SystemAssigned"
  }

  # Enable network plugin (Azure CNI or Kubenet)
  network_profile {
    network_plugin    = "azure"
    load_balancer_sku = "standard"
  }

}


resource "azurerm_public_ip" "vm1-pip" {
  name                = "vm-1-pip"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  allocation_method   = "Static"

  tags = {
    Created_By = "Terraform"
  }
}

resource "azurerm_network_interface" "vm1-nic" {
  name                = "vm-1-nic"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  ip_configuration {
    name                          = "internal"
    subnet_id                     = azurerm_subnet.main.id
    private_ip_address_allocation = "Static"
    private_ip_address            = "10.0.10.10"
    public_ip_address_id          = azurerm_public_ip.vm1-pip.id
  }

  tags = {
    Created_By = "Terraform"
  }
}


resource "azurerm_network_security_group" "vm1-nsg" {
  name                = "vm-1-nsg"
  location            = azurerm_resource_group.main.location
  resource_group_name = azurerm_resource_group.main.name

  security_rule {
    name                       = "allowSSHInbound"
    priority                   = 100
    direction                  = "Inbound"
    access                     = "Allow"
    protocol                   = "Tcp"
    source_port_range          = "*"
    destination_port_range     = "22"
    source_address_prefix      = "*"
    destination_address_prefix = "*"
  }

  tags = {
    Created_By = "Terraform"
  }
}

resource "azurerm_network_interface_security_group_association" "vm1-nic-nsg-assoc" {
  network_interface_id      = azurerm_network_interface.vm1-nic.id
  network_security_group_id = azurerm_network_security_group.vm1-nsg.id
}

resource "azurerm_linux_virtual_machine" "vm1" {
  name                = "KUBE-ADM"
  resource_group_name = azurerm_resource_group.main.name
  location            = azurerm_resource_group.main.location
  size                = "Standard_B2s"
  admin_username      = "vmadmin"
  network_interface_ids = [
    azurerm_network_interface.vm1-nic.id,
  ]

  admin_ssh_key {
    username   = "vmadmin"
    public_key = var.public_key
  }

  os_disk {
    caching              = "ReadWrite"
    storage_account_type = "Standard_LRS"
  }

  source_image_reference {
    publisher = "Canonical"
    offer     = "0001-com-ubuntu-server-jammy"
    sku       = "22_04-lts"
    version   = "latest"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Created_By = "Terraform"
  }
}

resource "azurerm_role_assignment" "aks_read" {
  scope                = azurerm_kubernetes_cluster.aks.id
  role_definition_name = "Azure Kubernetes Service Cluster User Role"
  principal_id         = azurerm_linux_virtual_machine.vm1.identity[0].principal_id
}

resource "null_resource" "install_az_cli" {
  provisioner "remote-exec" {
    connection {
      type        = "ssh"
      host        = azurerm_public_ip.vm1-pip.ip_address
      user        = "vmadmin"
      private_key = file(var.private_key_path)
    }

    inline = [
      <<-EOF
        sudo apt-get update
        sudo apt-get install -y apt-transport-https ca-certificates curl gnupg lsb-release

        sudo mkdir -p /etc/apt/keyrings
        curl -sLS https://packages.microsoft.com/keys/microsoft.asc | gpg --dearmor | sudo tee /etc/apt/keyrings/microsoft.gpg > /dev/null
        sudo chmod go+r /etc/apt/keyrings/microsoft.gpg

        AZ_DIST=$(lsb_release -cs)
        echo "Types: deb
        URIs: https://packages.microsoft.com/repos/azure-cli/
        Suites: $${AZ_DIST}
        Components: main
        Architectures: $(dpkg --print-architecture)
        Signed-by: /etc/apt/keyrings/microsoft.gpg" | sudo tee /etc/apt/sources.list.d/azure-cli.sources

        sudo apt-get update
        sudo apt-get install -y azure-cli
        sudo az aks install-cli

        # Wait 5 minutes for role assignment propagation
        echo "Waiting 5 minutes for Azure RBAC to propagate..."
        sleep 300

        az login --identity
        az aks get-credentials --resource-group rg-aks-test --name aks-demo --overwrite-existing
      EOF
    ]
  }

  depends_on = [azurerm_linux_virtual_machine.vm1]

}
