terraform {
  required_version = ">= 1.4.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = ">= 2.0, < 3.0"
    }
    azurerm = {
      source  = "hashicorp/azurerm"
      version = ">= 4.2, < 5.0"
    }
  }
}

provider "azapi" {
  subscription_id = var.subscription_id
}

provider "azurerm" {
  subscription_id = var.subscription_id

  features {}
}