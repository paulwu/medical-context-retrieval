terraform {
  backend "azurerm" {
    # Configured via -backend-config=environments/<env>.backend.tfvars
    # Usage: terraform init -backend-config=environments/exp.backend.tfvars
  }
}
