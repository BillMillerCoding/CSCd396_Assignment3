terraform {
  required_version = ">= 1.5.0"

  required_providers {
    azurerm = {
      source  = "hashicorp/azurerm"
      version = "~> 3.110"
    }
  }

  # Remote state stored in an Azure Storage Account.
  # The storage account and container must be created manually before running Terraform.
  # REQUIRED: Replace the storage_account_name value below with your actual state storage account name.
  # Set the following environment variables (or a backend config file) before running:
  #   ARM_STORAGE_ACCOUNT_NAME, ARM_CONTAINER_NAME, ARM_KEY
  backend "azurerm" {
    resource_group_name  = "rg-tfstate"
    storage_account_name = "REPLACE_WITH_STATE_STORAGE_ACCOUNT" # TODO: update this before first use
    container_name       = "tfstate"
    key                  = "assignment3.tfstate"
  }
}

provider "azurerm" {
  features {}
}
