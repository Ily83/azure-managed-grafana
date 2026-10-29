data "azapi_client_config" "current" {}

locals {
  resource_group_resource_id = "${data.azapi_client_config.current.subscription_resource_id}/resourceGroups/${var.resource_group_name}"
  role_assignments = merge(
    {
      for k, v in var.grafana_access : k => {
        principal_id               = v.principal_id
        principal_type             = v.principal_type
        role_definition_id_or_name = v.role
      }
    },
    # An explicit ID rather than "whoever runs Terraform": a local apply would otherwise move the grant away from the pipeline.
    var.deployment_principal_object_id == null ? {} : {
      deployment_principal = {
        principal_id               = var.deployment_principal_object_id
        principal_type             = "ServicePrincipal"
        role_definition_id_or_name = "Grafana Admin"
      }
    },
  )
}

module "grafana" {
  # The AVM module built on Azure/terraform-azurerm-avm-res-dashboard-grafana (no release yet), from the fork, pinned
  # to a commit. To try unpushed module changes, point this at a local clone of the fork; restore the pin before committing.
  source = "git::https://github.com/Ily83/terraform-azurerm-avm-res-dashboard-grafana.git?ref=66e0917f461c1f04ebeaa42c47946c280ef142bb"

  location        = var.location
  name            = var.grafana_name
  parent_id       = local.resource_group_resource_id
  api_key_enabled = var.api_key_enabled
  # Linking is a Grafana setting. The data-reader role on each workspace is granted by the workspace's own code.
  azure_monitor_workspace_integrations = {
    for k, v in var.azure_monitor_workspaces : k => {
      resource_id = "/subscriptions/${coalesce(v.subscription_id, data.azapi_client_config.current.subscription_id)}/resourceGroups/${v.resource_group_name}/providers/Microsoft.Monitor/accounts/${v.name}"
    }
  }
  deterministic_outbound_ip_enabled = var.deterministic_outbound_ip_enabled
  diagnostic_settings = var.log_analytics_workspace_resource_id == null ? {} : {
    law = {
      name                  = "diag-${var.grafana_name}"
      logs                  = [{ category_group = "allLogs" }]
      workspace_resource_id = var.log_analytics_workspace_resource_id
    }
  }
  enable_telemetry = var.enable_telemetry
  grafana_configurations = {
    snapshots_external_enabled = var.external_snapshots_enabled
  }
  grafana_major_version = var.grafana_major_version
  lock                  = var.lock_kind == null ? null : { kind = var.lock_kind }
  # Grafana reads Azure Monitor and managed Prometheus with this identity. The services it reads grant it access
  # themselves (see output grafana_principal_id), so this stack never writes into another service's scope.
  managed_identities = {
    system_assigned = true
  }
  private_endpoints = {
    for k, v in var.private_endpoints : k => {
      name                          = v.name
      subnet_resource_id            = v.subnet_resource_id
      private_dns_zone_resource_ids = v.private_dns_zone_resource_ids
    }
  }
  public_network_access_enabled = var.public_network_access_enabled
  role_assignments              = local.role_assignments
  sku_size                      = var.sku_size
  tags                          = var.tags
  zone_redundancy_enabled       = var.zone_redundancy_enabled
}
