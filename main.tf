# Based on:
# https://registry.terraform.io/providers/hashicorp/azurerm/latest/docs/resources/kubernetes_cluster

terraform {
  # Versions are hardcoded here so that every run resolves the same providers,
  # regardless of what `.terraform.lock.hcl` happens to contain. To upgrade,
  # bump the version below and run `tofu init -upgrade`.
  required_providers {
    azurerm = {
      source  = "registry.opentofu.org/hashicorp/azurerm"
      version = "5.4.0"
    }
  }
  backend "azurerm" {
    resource_group_name  = "tfstate"
    storage_account_name = "devopscoopterraform"
    container_name       = "tfstate"
    key                  = "terraform.tfstate"
  }
}

provider "azurerm" {
  features {
    key_vault {
      purge_soft_deleted_keys_on_destroy = true
      recover_soft_deleted_keys          = true
    }
  }
}

resource "azurerm_resource_group" "devopscoop" {
  name     = "devopscoop"
  location = "West US 2"
}

resource "azurerm_kubernetes_cluster" "devopscoop" {
  location            = azurerm_resource_group.devopscoop.location
  name                = "devopscoop"
  resource_group_name = azurerm_resource_group.devopscoop.name
  dns_prefix          = "devopscoop"
  # You can get available versions with this command:
  # az aks get-upgrades --resource-group devopscoop --name devopscoop --output table
  kubernetes_version = "1.36.3"

  # Enabling OIDC and Workload Identity so external-dns and cert-manager can manage DNS records in Azure DNS.
  oidc_issuer_enabled       = true
  workload_identity_enabled = true

  identity {
    type = "SystemAssigned"
  }

  # Required as of azurerm 5.x. "Manual" means we manage node pools ourselves
  # (the default_node_pool below). "Auto" would hand provisioning to
  # Karpenter-style node auto-provisioning.
  node_provisioning_profile {
    mode = "Manual"
  }

  default_node_pool {
    name       = "agentpool"
    vm_size    = "Standard_B2as_v2"
    node_count = var.node_count

    # This "optional" setting is needed if you ever want to actually change one
    # of like 15 other settings in your cluster. More Azure nonsense - just
    # create a new node pool with timestamp to make it unique or something. WTF
    # Azure!
    temporary_name_for_rotation = "wtfazure"

  }

}

resource "azurerm_virtual_network" "devopscoop" {
  name                = "devopscoop"
  address_space       = ["10.0.0.0/16"]
  location            = azurerm_resource_group.devopscoop.location
  resource_group_name = azurerm_resource_group.devopscoop.name
}

resource "azurerm_subnet" "devopscoop" {
  name                 = "devopscoop"
  resource_group_name  = "devopscoop"
  virtual_network_name = azurerm_virtual_network.devopscoop.name
  address_prefixes     = ["10.0.1.0/24"]

  # Was the `service_endpoints` list argument before azurerm 5.x.
  service_endpoint {
    service = "Microsoft.Storage"
  }
}

# Ran:
# terraform import azurerm_dns_zone.sandbox /subscriptions/REDACTED/resourceGroups/devopscoop/providers/Microsoft.Network/dnszones/sandbox.devops.coop
# but it failed. I copied the id directly from the Azure portal, but lo and behold, you have to have a capital "Z" like this to make it work:
# terraform import azurerm_dns_zone.sandbox /subscriptions/REDACTED/resourceGroups/devopscoop/providers/Microsoft.Network/dnsZones/sandbox.devops.coop
resource "azurerm_dns_zone" "sandbox" {
  name                = "sandbox.devops.coop"
  resource_group_name = azurerm_resource_group.devopscoop.name
}
resource "azurerm_dns_zone" "prod" {
  name                = "prod.devops.coop"
  resource_group_name = azurerm_resource_group.devopscoop.name
}
resource "azurerm_dns_zone" "dev" {
  name                = "dev.devops.coop"
  resource_group_name = azurerm_resource_group.devopscoop.name
}
