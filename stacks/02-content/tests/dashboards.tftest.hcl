# Renders every file under dashboards/ through the content module with mocked providers, so broken JSON,
# unescaped `$${...}` in .json.tftpl files or duplicate UIDs fail without Azure or Grafana access:
#   terraform init -backend=false && terraform test
mock_provider "azapi" {
  mock_data "azapi_client_config" {
    defaults = {
      subscription_resource_id = "/subscriptions/00000000-0000-0000-0000-000000000000"
    }
  }
  mock_data "azapi_resource" {
    defaults = {
      output = {
        properties = {
          endpoint            = "https://amg-test.weu.grafana.azure.com"
          grafanaMajorVersion = "12"
        }
      }
    }
  }
}

mock_provider "grafana" {}

variables {
  grafana_name        = "amg-test"
  resource_group_name = "rg-test"
}

run "grafana_12" {
  command = plan

  assert {
    condition     = length(module.content.dashboards) == length(distinct([for f in fileset("${path.module}/../../dashboards", "*/*.{json,json.tftpl}") : f]))
    error_message = "Every dashboard file must produce exactly one dashboard."
  }
  assert {
    condition     = local.prometheus_datasource_type == "prometheus"
    error_message = "Grafana 12 must use the core Prometheus data source type."
  }
}

run "grafana_13" {
  command = plan

  override_data {
    target = data.azapi_resource.grafana
    values = {
      output = {
        properties = {
          endpoint            = "https://amg-test.weu.grafana.azure.com"
          grafanaMajorVersion = "13"
        }
      }
    }
  }

  assert {
    condition     = local.prometheus_datasource_type == "grafana-azureprometheus-datasource"
    error_message = "Grafana 13 must use the Azure Monitor managed Prometheus plugin type."
  }
}
