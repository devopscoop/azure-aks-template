# resource "azurerm_resource_group" "devopscoop" {
#   name     = "devopscoop-resources"
#   location = "West Europe"
# }

resource "azurerm_data_protection_backup_vault" "devopscoop" {
  name                = "devopscoop-backup-vault"
  resource_group_name = azurerm_resource_group.devopscoop.name
  location            = azurerm_resource_group.devopscoop.location
  datastore_type      = "VaultStore"
  redundancy          = "LocallyRedundant"
}

resource "azurerm_data_protection_backup_policy_disk" "devopscoop" {
  name     = "devopscoop-backup-policy"
  vault_id = azurerm_data_protection_backup_vault.devopscoop.id

  backup_repeating_time_intervals = ["R/2021-05-19T06:33:16+00:00/PT4H"]
  default_retention_duration      = "P7D"
  #   time_zone                       = "W. Europe Standard Time"

  retention_rule {
    name     = "Daily"
    duration = "P7D"
    priority = 25
    criteria {
      absolute_criteria = "FirstOfDay"
    }
  }

  retention_rule {
    name     = "Weekly"
    duration = "P7D"
    priority = 20
    criteria {
      absolute_criteria = "FirstOfWeek"
    }
  }
}
