import {
  to = azurerm_key_vault.devopscoop-argocd
  id = "/subscriptions/REDACTED/resourceGroups/devopscoop/providers/Microsoft.KeyVault/vaults/devopscoop-argocd"
}

import {
  to = azurerm_user_assigned_identity.argocd-identity
  id = "/subscriptions/REDACTED/resourceGroups/devopscoop/providers/Microsoft.ManagedIdentity/userAssignedIdentities/argocd"
}

import {
  to = azurerm_key_vault_key.sops-key
  id = "https://devopscoop-argocd.vault.azure.net/keys/sops-key/REDACTED"
}
