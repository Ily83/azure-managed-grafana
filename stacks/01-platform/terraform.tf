terraform {
  required_version = ">= 1.11, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.13"
    }
    random = {
      source  = "hashicorp/random"
      version = "~> 3.9"
    }
  }

  # Partial configuration: storage_account_name, container_name and key are passed with
  # -backend-config by the pipeline (see pipelines/templates/deploy-grafana.yml).
  backend "azurerm" {
    use_azuread_auth = true
  }
}

provider "azapi" {}
