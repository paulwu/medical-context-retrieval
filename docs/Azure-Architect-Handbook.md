# Azure Architect Agent — Handbook

This document explains how to use the **Azure Architect** Copilot agent for Terraform
infrastructure work in the Medical Context Retrieval project.

## What is the Azure Architect Agent?

The Azure Architect is a **single, consolidated agent** that handles the complete Terraform
lifecycle. It replaces four previously separate agents:

| Previous Agent | What It Did | Now Part Of |
|---|---|---|
| `terraform-azure-planning.agent.md` | Created INFRA implementation plans | Azure Architect — Phase 1 (Planning) |
| `terraform-azure-implement.agent.md` | Wrote Terraform code from plans | Azure Architect — Phase 2 (Implementation) |
| `terraform.agent.md` | HCP Terraform MCP server integration | **Removed** — not applicable (we use Azure Storage backend) |
| `azure-verified-modules-terraform.md` | AVM enforcement | **Removed** — covered by instruction file at `.github/instructions/azure-verified-modules-terraform.instructions.md` |

## Remaining Agents

After consolidation, the project has **4 focused agents**:

| Agent | Purpose | When to Use |
|---|---|---|
| **Azure Architect** | Full lifecycle: plan → implement → validate → apply → commit | Any infrastructure change |
| **Terraform IaC Reviewer** | Code review and audit | Reviewing PRs or existing code |
| **Drift Reconciliation** | Detect and fix drift between code and Azure | Periodic maintenance |
| **Architecture Documentor** | Generate architecture docs with Mermaid diagrams | Documentation updates |

## How to Invoke

In VS Code Copilot Chat, type:

```
@Azure-Architect <your request>
```

Examples:

```
@Azure-Architect Add a new Cosmos DB container for medical guidelines
@Azure-Architect Upgrade the AI Search SKU from basic to standard
@Azure-Architect Create an INFRA plan for adding a Redis cache
```

## Workflow Phases

The agent follows a strict 8-phase workflow. Every phase must complete before the next begins.

### Phase 0 — Environment Confirmation

The agent confirms which environment is active using `env-select.sh`, verifies the
Azure CLI session, and checks for uncommitted git changes.

### Phase 1 — Planning (New — Merged from Planning Agent)

For significant changes, the agent creates a structured implementation plan:

- Classifies the change scope (quick fix, new resource, architecture change)
- Creates an `INFRA.{goal}.md` plan file in `.terraform-planning-files/`
- Includes WAF alignment (Cost, Reliability, Security, Performance, Ops Excellence)
- References Microsoft documentation for each Azure resource
- Prefers Azure Verified Modules (AVM) with pinned versions
- Generates architecture and network diagrams

**For quick fixes**, this phase is skipped — the agent proceeds directly to implementation.

### Phase 2 — Implementation (New — Merged from Implementation Agent)

The agent writes Terraform code following project conventions:

- Uses deployment switches (`deploy_*` variables)
- Follows CAF naming via `locals.tf`
- Updates `locals_cost.tf` for new services
- Adds `checks.tf` cost warnings for expensive resources
- Prefers implicit dependencies over `depends_on`
- Validates against INFRA plans if they exist
- Removes dead code (unused variables, locals, outputs)

### Phase 3 — Format and Validate

```bash
terraform fmt -recursive
terraform validate
```

### Phase 4 — Terraform Plan

Runs `terraform plan`, presents a summary table, and asks the user to approve
before proceeding.

### Phase 5 — Terraform Apply

Only runs after explicit user confirmation. Never auto-applies.

### Phase 6 — Verify Deployment

Runs `terraform plan` again to confirm zero drift after apply.

### Phase 7 — Git Commit and Push

Stages changes, proposes a conventional commit message with `Plan-Status:` and
`Co-authored-by:` trailers, and pushes after user approval.

## Guardrails

The agent enforces strict rules:

- **Never** modifies backend storage account name or resource group
- **Never** enables public endpoints to work around connectivity issues
- **Never** commits without `terraform validate` passing
- **Never** auto-applies without user confirmation
- **Always** includes `Plan-Status:` trailer in commit messages
- **Always** asks before running destructive commands

## New Capabilities (from Agent Consolidation)

### 1. Integrated Planning

Previously, you had to invoke the planning agent separately, then switch to the
implementation agent. Now the Azure Architect handles both:

```
@Azure-Architect Plan and implement a new Azure Redis Cache for session storage
```

The agent will create the INFRA plan, then implement it — all in one session.

### 2. AVM-Aware Implementation

Azure Verified Module best practices from the former AVM agent are now built in:

- Automatically checks for AVM modules before using raw resources
- Pins module versions from the Terraform Registry
- Follows AVM naming conventions (`Azure/avm-res-{service}-{resource}/azurerm`)

### 3. Quality Tools Integration

From the implementation agent, the Azure Architect now offers:

- **tflint** for advanced static analysis
- **terraform-docs** for documentation generation
- **tfsec/checkov** for security scanning
- **Pre-commit hooks** configuration

### 4. Local State Support

The agent now recognizes local-state environments and adjusts its workflow:

- Skips Azure CLI verification for local environments
- Uses `terraform init -backend=false` automatically
- Warns about state portability limitations

### 5. Cost Awareness

The agent references `locals_cost.tf` and `checks.tf` to:

- Warn about expensive SKUs during planning
- Suggest cost-optimized alternatives for dev/test
- Add cost check blocks for new services

## Environment Support

The agent works with the `env-select.sh` system:

```bash
# Select development environment (Azure backend)
bash infrastructure/scripts/env-select.sh dev

# Select local environment (no remote state)
bash infrastructure/scripts/env-select.sh local

# Check current environment
bash infrastructure/scripts/env-select.sh --current
```

See [Environment-Variables-Handbook.md](Environment-Variables-Handbook.md) for details.

## Quick Reference

```bash
# Full happy-path sequence
bash infrastructure/scripts/env-select.sh dev
bash infrastructure/scripts/tf.sh init
terraform fmt -recursive && terraform validate
bash infrastructure/scripts/tf.sh plan
bash infrastructure/scripts/tf.sh apply
git add -A && git commit -m "feat: description

Plan-Status: applied
Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>"
git push origin main
```
