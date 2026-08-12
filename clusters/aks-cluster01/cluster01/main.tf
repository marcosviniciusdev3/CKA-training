# Create Resource Group
resource "azurerm_resource_group" "rg" {
  name     = "aks-cluster01"
  location =  var.default_location 
}

resource "azurerm_virtual_network" "aks_cluster01" {
  name                = "aks-cluster01"
  resource_group_name = azurerm_resource_group.rg.name
  location            = azurerm_resource_group.rg.location
  address_space       = ["10.0.0.0/16"]
}

resource "azurerm_kubernetes_cluster" "aks_cluster01" {
  name                = "aks-cluster01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "aks-cluster01"

  node_provisioning_profile {
    default_node_pools = "Auto"
  }
  
  default_node_pool {
    name       = "systempool"
    node_count = 2
    vm_size    = "Standard_B2s"
    os_sku     = "Ubuntu"
  }

  identity {
    type = "SystemAssigned"
  }

  tags = {
    Environment = "Development"
  }
}
