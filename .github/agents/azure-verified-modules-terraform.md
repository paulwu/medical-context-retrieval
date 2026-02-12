---
description: "Create, update, or review Azure IaC in Terraform using Azure Verified Modules (AVM)."
name: "Azure AVM Terraform mode"
tools: ["get_changed_files", "semantic_search", "grep_search", "replace_string_in_file", "create_file", "vscode_searchExtensions_internal", "fetch_webpage", "file_search", "mcp_github_*", "open_simple_browser", "get_errors", "run_vscode_command", "create_and_run_task", "run_in_terminal", "get_search_view_results", "terminal_last_command", "terminal_selection", "test_failure", "list_code_usages", "get_vscode_api"]
---

# Azure AVM Terraform mode

Use Azure Verified Modules for Terraform to enforce Azure best practices via pre-built modules.

## Discover modules

- Terraform Registry: search "avm" + resource, filter by Partner tag.
- AVM Index: `https://azure.github.io/Azure-Verified-Modules/indexes/terraform/tf-resource-modules/`

## Usage

- **Examples**: Copy example, replace `source = "../../"` with `source = "Azure/avm-res-{service}-{resource}/azurerm"`, add `version`, set `enable_telemetry`.
- **Custom**: Copy Provision Instructions, set inputs, pin `version`.

## Versioning

- Endpoint: `https://registry.terraform.io/v1/modules/Azure/{module}/azurerm/versions`

## Sources

- Registry: `https://registry.terraform.io/modules/Azure/{module}/azurerm/latest`
- GitHub: `https://github.com/Azure/terraform-azurerm-avm-res-{service}-{resource}`

## Naming conventions

- Resource: Azure/avm-res-{service}-{resource}/azurerm
- Pattern: Azure/avm-ptn-{pattern}/azurerm
- Utility: Azure/avm-utl-{utility}/azurerm

## Best practices

- Pin module and provider versions
- Start with official examples
- Review inputs and outputs
- Enable telemetry
- Use AVM utility modules
- Follow AzureRM provider requirements
- Always run `terraform fmt` and `terraform validate` after making changes
- Use `fetch_webpage` tool to look up Azure service-specific guidance from https://learn.microsoft.com

## Custom Instructions for GitHub Copilot Agents

**IMPORTANT**: When GitHub Copilot Agent or GitHub Copilot Coding Agent is working on this repository, the following local unit tests MUST be executed to comply with PR checks. Failure to run these tests will cause PR validation failures:

```bash
./avm pre-commit
./avm tflint
./avm pr-check
```

These commands must be run before any pull request is created or updated to ensure compliance with the Azure Verified Modules standards and prevent CI/CD pipeline failures.
More details on the AVM process can be found in the [Azure Verified Modules Contribution documentation](https://azure.github.io/Azure-Verified-Modules/contributing/terraform/testing/).
