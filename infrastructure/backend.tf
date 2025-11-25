terraform {
  backend "azurerm" {
    resource_group_name   = "EXP-HLS-MedicalContext-RG"
    storage_account_name  = "medctxtfstate"
    container_name        = "tfstate"
    key                   = "state"
  }
}
