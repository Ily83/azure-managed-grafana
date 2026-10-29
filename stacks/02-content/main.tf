data "azapi_client_config" "current" {}

# Looked up rather than read from the platform state, so this stack also works against a workspace managed elsewhere.
data "azapi_resource" "grafana" {
  name      = var.grafana_name
  parent_id = "${data.azapi_client_config.current.subscription_resource_id}/resourceGroups/${var.resource_group_name}"
  type      = "Microsoft.Dashboard/grafana@2025-08-01"
  response_export_values = [
    "properties.endpoint",
    "properties.grafanaMajorVersion",
  ]
}

locals {
  grafana_major_version = try(data.azapi_resource.grafana.output.properties.grafanaMajorVersion, "12")
  # From Grafana 13, Azure authentication for managed Prometheus is only available in the dedicated plugin.
  prometheus_datasource_type = tonumber(local.grafana_major_version) >= 13 ? "grafana-azureprometheus-datasource" : "prometheus"
}

module "content" {
  source = "../../modules/grafana-content"

  dashboard_template_variables = merge(
    {
      grafana_major_version      = local.grafana_major_version
      prometheus_datasource_type = local.prometheus_datasource_type
    },
    var.dashboard_template_variables,
  )
  dashboards_directory = "${path.module}/../../dashboards"
  data_sources         = var.data_sources
  folders              = var.folders
}
