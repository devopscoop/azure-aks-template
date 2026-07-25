# AGENTS.md

Instructions for AI coding agents working in this repo.

## What this repo is

A single root OpenTofu configuration (no modules, no workspaces, no submodule
directories) that provisions an AKS cluster and its supporting Azure resources.
Every `.tf` file at the repo root is part of one configuration and one state
file:

| File | Contents |
| --- | --- |
| `main.tf` | `terraform` block (azurerm backend + provider), resource group, AKS cluster, VNet/subnet, three DNS zones |
| `keyvault.tf` | The original `devopscoop` Key Vault + `sops` key. **Obsolete** — see landmines |
| `keyvault-argo.tf` | The in-use `devopscoop-argocd` Key Vault, `sops-key`, Argo CD user-assigned identity, access policy, and federated identity credential |
| `backups.tf` | Data protection backup vault + disk backup policy |
| `imports.tf` | `import {}` blocks adopting pre-existing Argo CD resources |
| `variables.tf` | `node_count` (default 1) — the only variable in the repo |

Resource names are hard-coded to `devopscoop` throughout, and the region is
hard-coded to West US 2. Despite the repo name, forking this as a "template"
means renaming resources by hand rather than setting variables.

## Commands

OpenTofu is invoked as `tofu`, never `terraform`. It is installed and pinned by
tenv, which reads `.opentofu-version` (currently 1.10.5) so local runs match CI:

```shell
tenv tofu install          # installs the version in .opentofu-version
```

The full local check sequence, matching what CI runs:

```shell
tofu fmt -recursive -check                                  # CI runs this (non-blocking)
tofu init                                                   # needs ARM_ACCESS_KEY for the azurerm backend
tofu validate -no-color
tofu plan -concise -no-color -input=false -out=plan.file
```

There is no test suite and no linter beyond `tofu fmt` and `tofu validate`.

Azure auth for both local and CI runs comes from environment variables:
`ARM_ACCESS_KEY` (backend state access), `ARM_CLIENT_ID`, `ARM_CLIENT_SECRET`,
`ARM_SUBSCRIPTION_ID`, `ARM_TENANT_ID`.

Other routine commands:

```shell
az aks get-credentials --resource-group devopscoop --name devopscoop
tofu init -upgrade          # provider bumps; commit the resulting .terraform.lock.hcl changes
```

## How changes reach Azure

`.github/workflows/opentofu.yml` owns the apply. Opening a PR against `main`
runs `fmt`/`init`/`validate`/`plan` and posts the plan as a PR comment; any push
to `main`, including a merge, runs `tofu apply` against the saved `plan.file`.

**Do not run `tofu apply` locally.** State is shared, and `keyvault.tf` carries
an explicit warning that a local apply can rewrite the Key Vault access policy
to whichever principal ran it, which breaks the pipeline. Local runs should stop
at `plan`.

To destroy the cluster, add `-destroy` to the `tofu plan` and `tofu apply` lines
in `.github/workflows/opentofu.yml` (per README.md).

## Landmines

These are non-obvious and cost real time if rediscovered:

- **`imports.tf` IDs are scrubbed.** All three `import {}` block IDs are the
  literal string `REDACTED`, so `tofu plan` will fail until real subscription
  and key IDs are restored. The three resources
  (`azurerm_key_vault.devopscoop-argocd`,
  `azurerm_user_assigned_identity.argocd-identity`,
  `azurerm_key_vault_key.sops-key`) are adopted from resources created out of
  band, not created by this config.
- **Two Key Vaults, one of them dead.** `keyvault.tf` is marked obsolete by a
  TODO at the top: the sops key actually in use is `sops-key` in the
  `devopscoop-argocd` vault (`keyvault-argo.tf`). Add new Key Vault work to
  `keyvault-argo.tf`.
- **Do not "fix" the hard-coded `object_id`s in `keyvault.tf`.** They are
  deliberately literal. Using `data.azurerm_client_config.current.object_id`
  there sets the access policy to whichever principal runs apply, which breaks
  the pipeline. The documented proper fix is a data lookup on the `terraform`
  application.
- **`temporary_name_for_rotation = "wtfazure"`** in the default node pool is
  load-bearing: AKS requires it to change most other node pool settings in
  place. Don't remove it.
- **Pinned versions with no constraints.** `kubernetes_version = "1.28.5"` is
  hard-coded in `main.tf`, and `required_providers` declares azurerm with no
  version constraint — the version is held only by `.terraform.lock.hcl`
  (3.98.0).
- **Argo CD's Kubernetes service account is not managed here.** The
  `kubernetes_service_account` resource in `keyvault-argo.tf` is commented out
  because OpenTofu has no cluster credentials (chicken-and-egg). The federated
  identity credential's subject
  (`system:serviceaccount:argocd:aks-argocd`) assumes that service account is
  created elsewhere.
- **`.sops.yaml` is entirely commented out.** sops is not wired up, and it is
  intentionally absent from the package manifests.

## Stale references — verify before trusting

Several docs and configs disagree with the code. Treat the `.tf` files as truth:

- `.github/workflows/opentofu.yml` sets `tofu_version_file:
  cluster/.opentofu-version`, but the file lives at the repo root; no `cluster/`
  directory exists anywhere in this repo's history.
- README.md's bootstrap section uses storage account `devopscoopopentofu`, while
  the backend in `main.tf` is `devopscoopterraform`. README links also point at
  `devopscoop/cluster-tf`, and a comment in the workflow points at
  `Equal-Vote/terraform`.
- `.github/dependabot.yml` has an empty `package-ecosystem: ""` placeholder, so
  it updates nothing as configured.

## Package manifests

This repo ships a `Brewfile` (macOS: `brew bundle`) and a `pkglist.txt` (Arch Linux) that install every CLI tool the repo uses. Keep them in sync with the code:

- When you add a tool, script, or a new external command inside an existing script, add the package to BOTH files, with a comment noting what uses it.
- When a tool stops being used, remove it from both files.
- Verify package names before adding them: `brew info <formula>` for Homebrew, and the official repos/AUR for Arch (e.g. kubectl is Homebrew `kubernetes-cli` but Arch `kubectl`; tenv is Arch's AUR `tenv-bin`). If a package is AUR-only, note that in pkglist.txt's header instructions.
- Update the "Install required packages" section in README.md if the tool list changes.
- OpenTofu is managed by tenv (which reads `.opentofu-version`) — never add `opentofu` directly to the manifests.

## GitHub Actions conventions

- Pin every action to a full commit SHA with the version as a trailing comment
  (`uses: actions/checkout@3d3c42e... # v7.0.1`). This is enforced by habit
  across all workflows, including the Claude ones.
- The Claude workflows (`claude.yml` for `@claude` mentions, and
  `claude-code-review.yml` for automatic PR review) are pinned to
  `--model claude-opus-5 --effort xhigh`. Both carry long comments explaining
  their permission scoping and why the code-review plugin is deliberately not
  used — read those comments before changing tool allowlists or permissions,
  because the choices there are intentional rather than accidental.
