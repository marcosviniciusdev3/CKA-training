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

resource "azurerm_subnet" "aks_subnet" {
  name                 = "aks-subnet"
  resource_group_name  = azurerm_resource_group.rg.name
  virtual_network_name = azurerm_virtual_network.aks_cluster01.name
  address_prefixes     = ["10.0.1.0/24"]
}
resource "azurerm_kubernetes_cluster" "aks_cluster01" {
  name                = "aks-cluster01"
  location            = azurerm_resource_group.rg.location
  resource_group_name = azurerm_resource_group.rg.name
  dns_prefix          = "aks-cluster01"

  node_provisioning_profile {
    mode = "Manual"
  }

  default_node_pool {
    name       = "systempool"
    node_count = 1
    vm_size    = "Standard_B2s"
    os_sku     = "Ubuntu"
    only_critical_addons_enabled  = true
    vnet_subnet_id                = azurerm_subnet.aks_subnet.id
  }

  identity {
    type = "SystemAssigned"
  }

  network_profile {
    network_plugin = "azure"
  }

  tags = {
    ManagedBy = "terraform"
    OwnedBy = "marcosviniciusdev3"
  }
}

resource "azurerm_kubernetes_cluster_node_pool" "dev01pool" {
  name                  = "dev01pool"
  kubernetes_cluster_id = azurerm_kubernetes_cluster.aks_cluster01.id
  vm_size               = "Standard_B2s"
  node_count            = 1
  vnet_subnet_id        = azurerm_subnet.aks_subnet.id

  node_labels = {
    environment = "development"
  }
}
