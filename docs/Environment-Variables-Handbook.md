# Environment Variables Handbook

This document explains how to manage Terraform environments in the Medical Context
Retrieval project, including how to use local state for offline development.

## Overview

The project uses an **environment management system** that supports multiple deployment
targets. Each environment has its own variable values and backend configuration.

### Components

| File | Purpose |
|---|---|
| `environments/environments.json` | Registry of all environments |
| `environments/*.tfvars` | Variable values per environment |
| `environments/*.backend.tfvars` | Backend config per environment |
| `infrastructure/scripts/env-select.sh` | Environment picker script |
| `infrastructure/scripts/tf.sh` | Terraform wrapper with auto-injection |
| `.current-env` | Persists the active environment (git-ignored) |

## Available Environments

| Name | Alias | Backend | Description |
|---|---|---|---|
| `medical-ctx-dev` | `dev` | Azure Storage (remote) | Development with shared state |
| `medical-ctx-local` | `local` | Local file | Offline development, validation only |

## Selecting an Environment

### Interactive picker

```bash
bash infrastructure/scripts/env-select.sh
```

Displays all environments and prompts for selection by number.

### Direct selection (by alias or name)

```bash
bash infrastructure/scripts/env-select.sh dev
bash infrastructure/scripts/env-select.sh local
bash infrastructure/scripts/env-select.sh medical-ctx-dev
```

### Check current environment

```bash
bash infrastructure/scripts/env-select.sh --current
```

### List all environments

```bash
bash infrastructure/scripts/env-select.sh --list
```

## Using the Terraform Wrapper

After selecting an environment, use `tf.sh` instead of raw `terraform` commands.
It automatically injects the correct `-var-file` and `-backend-config` flags.

```bash
bash infrastructure/scripts/tf.sh init       # terraform init with backend config
bash infrastructure/scripts/tf.sh plan       # terraform plan with var-file
bash infrastructure/scripts/tf.sh apply      # terraform apply with var-file
bash infrastructure/scripts/tf.sh validate   # terraform validate (no var-file needed)
bash infrastructure/scripts/tf.sh fmt        # terraform fmt (no var-file needed)
```

### What tf.sh does automatically

1. Reads `.current-env` to find the active environment
2. Looks up `tfvars` and `backend` paths from `environments.json`
3. Extracts `subscription_id` from the tfvars file
4. Sets `ARM_SUBSCRIPTION_ID` environment variable
5. Displays an environment banner (e.g., `📍 medical-ctx-dev (dev) | sub: ...1234`)
6. Appends `-var-file=...` to plan/apply/destroy commands
7. Appends `-backend-config=...` to init commands

### Fallback behavior

If no environment is selected (`environments.json` or `.current-env` doesn't exist),
`tf.sh` falls back to:
1. Using `ARM_SUBSCRIPTION_ID` if already set in the shell
2. Querying `az account show` to get the active subscription

## Using Local State

Local state is useful for:
- **Offline development** without Azure connectivity
- **Syntax validation** and `terraform plan` previews
- **Learning and experimentation** without affecting shared state
- **CI validation** in environments without Azure Storage access

### Setup

1. **Select the local environment:**

   ```bash
   bash infrastructure/scripts/env-select.sh local
   ```

2. **Edit the local tfvars** (optional — update `subscription_id` for plan):

   ```bash
   # Edit environments/local.tfvars
   # Set subscription_id to your real subscription if you want plan to work
   ```

3. **Initialize with local state:**

   ```bash
   bash infrastructure/scripts/tf.sh init
   ```

   This automatically detects the empty `backend` field and runs
   `terraform init -backend=false`.

4. **Validate and plan:**

   ```bash
   bash infrastructure/scripts/tf.sh validate
   bash infrastructure/scripts/tf.sh plan      # Requires az login if subscription_id is real
   ```

### How it works

When the selected environment has an empty `backend` field in `environments.json`:

```json
{
  "medical-ctx-local": {
    "alias": "local",
    "description": "Local development — no remote state",
    "tfvars": "environments/local.tfvars",
    "backend": ""
  }
}
```

The `tf.sh` wrapper detects the empty backend and passes `-backend=false` to
`terraform init`. This means:

- **No remote state** — Terraform won't connect to Azure Storage
- **`validate` works** — Syntax and type checking function normally
- **`plan` works** — If you have a valid `subscription_id` and `az login` session
- **`apply` creates local state** — A `terraform.tfstate` file is created locally
  (git-ignored by `.gitignore`)
- **State is NOT shared** — Only exists on your machine

### Limitations

| Capability | Remote (dev) | Local |
|---|---|---|
| `terraform validate` | ✅ | ✅ |
| `terraform plan` | ✅ | ✅ (requires `az login`) |
| `terraform apply` | ✅ | ✅ (local state only) |
| Shared state | ✅ | ❌ |
| State locking | ✅ | ❌ |
| Team collaboration | ✅ | ❌ |
| CI/CD integration | ✅ | ❌ |

### Switching between local and remote

```bash
# Switch to local for offline work
bash infrastructure/scripts/env-select.sh local
bash infrastructure/scripts/tf.sh init

# Switch back to remote for deployment
bash infrastructure/scripts/env-select.sh dev
bash infrastructure/scripts/tf.sh init    # Re-initializes with Azure Storage backend
```

> **Important:** When switching between local and remote backends, Terraform will
> ask if you want to migrate state. Choose carefully:
> - **Local → Remote:** Answer "yes" only if your local state has changes you want to keep
> - **Remote → Local:** Answer "yes" to get a local copy of the remote state

## Adding a New Environment

1. **Create a tfvars file:**

   ```bash
   cp environments/terraform.tfvars.example environments/staging.tfvars
   # Edit staging.tfvars with your values
   ```

2. **Create a backend config** (skip for local-only environments):

   ```bash
   cp environments/backend.tfvars.example environments/staging.backend.tfvars
   # Edit with your state storage account details
   ```

3. **Register in environments.json:**

   ```json
   {
     "environments": {
       "medical-ctx-staging": {
         "alias": "staging",
         "description": "Staging environment — pre-production",
         "tfvars": "environments/staging.tfvars",
         "backend": "environments/staging.backend.tfvars"
       }
     }
   }
   ```

4. **Select and initialize:**

   ```bash
   bash infrastructure/scripts/env-select.sh staging
   bash infrastructure/scripts/tf.sh init
   ```

## Variable Files Reference

### terraform.tfvars.example

Complete example with all variables. Copy to create new environments.
Located at: `environments/terraform.tfvars.example`

### backend.tfvars.example

Backend configuration template for Azure Storage state.
Located at: `environments/backend.tfvars.example`

### Key variables

| Variable | Required | Description |
|---|---|---|
| `subscription_id` | Yes | Azure subscription ID |
| `environment` | Yes | `dev`, `qa`, `prod`, `jp`, or `demo` |
| `organization_prefix` | Yes | 2-9 alphanumeric chars for naming |
| `location` | No | Azure region (default: West US 3) |
| `deploy_*` | No | Feature flags for optional services |

### Deployment switches

Toggle services on/off per environment:

```hcl
deploy_infrastructure           = true   # Base infra (RG, storage, etc.)
deploy_private_network          = true   # VNet + private endpoints
deploy_ai_foundry_instances     = true   # AI Foundry account
deploy_ai_model_deployments     = true   # GPT-4o + embeddings
deploy_container_app_environment = true  # Container Apps
deploy_ai_search                = true   # Azure AI Search
deploy_azure_frontdoor          = false  # Front Door CDN
```

## Security Notes

- **Never commit** `.tfvars` files with real subscription IDs or secrets
- The `.gitignore` excludes `*.tfvars` but whitelists `*.tfvars.example`
- Use Key Vault references for sensitive values (API keys, connection strings)
- The `.current-env` file is git-ignored — safe to use locally
