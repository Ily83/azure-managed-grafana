terraform {
  required_version = ">= 1.11, < 2.0"

  required_providers {
    azapi = {
      source  = "Azure/azapi"
      version = "~> 2.13"
    }
    grafana = {
      source  = "grafana/grafana"
      version = "~> 4.52"
    }
  }

  # Partial configuration: storage_account_name, container_name and key are passed with
  # -backend-config by the pipeline (see pipelines/templates/deploy-grafana.yml).
  backend "azurerm" {
    use_azuread_auth = true
  }
}

provider "azapi" {}

# Authentication comes from the GRAFANA_AUTH environment variable, set to a Microsoft Entra access token:
#   export GRAFANA_AUTH=$(az account get-access-token --resource https://dashboard.azure.com --query accessToken -o tsv)
# The identity needs the Grafana Admin (or Grafana Editor) role on the workspace. No API key or service account is needed.
provider "grafana" {
  url = data.azapi_resource.grafana.output.properties.endpoint
}
