grafana_name        = "axso4np4nonp4psvc4amg"
resource_group_name = "axso-np-appl-psvc-nonprod-rg"

# The nonprod workspace already exists: adopt it instead of creating a new one.
import_existing_grafana = true

# TODO before the first apply: these MUST match the existing workspace. A wrong location or zone redundancy replaces it,
# deleting every dashboard. The others change behaviour in place. Read the current values with:
#   az grafana show -g axso-np-appl-psvc-nonprod-rg -n axso4np4nonp4psvc4amg --query "{location:location, sku:sku, version:properties.grafanaMajorVersion, zoneRedundancy:properties.zoneRedundancy, apiKey:properties.apiKey, outboundIp:properties.deterministicOutboundIP, publicAccess:properties.publicNetworkAccess, externalSnapshots:properties.grafanaConfigurations.snapshots.externalEnabled}"
location                          = "westeurope"
zone_redundancy_enabled           = false
grafana_major_version             = "12"
sku_size                          = "X1"
api_key_enabled                   = false
deterministic_outbound_ip_enabled = false

# Network access. With no private endpoint, public access stays on (null = automatic). To make the workspace private,
# add an endpoint; public access then turns off unless public_network_access_enabled = true.
# public_network_access_enabled = true
# private_endpoints = {
#   hub = {
#     subnet_resource_id            = "/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/virtualNetworks/<vnet>/subnets/<subnet>"
#     private_dns_zone_resource_ids = ["/subscriptions/<sub>/resourceGroups/<rg>/providers/Microsoft.Network/privateDnsZones/privatelink.grafana.azure.com"]
#   }
# }

# External snapshot publishing is off by default. The service default is on, so the first plan of this imported
# workspace turns it off if the query above shows externalSnapshots = true. Keep it on with:
# external_snapshots_enabled = true

# Linked as a data source only. Monitoring Data Reader for Grafana is granted by the code that manages this workspace.
azure_monitor_workspaces = {
  pushservice = {
    name                = "axso-np-appl-psvc-nonprod-mws"
    resource_group_name = "axso-np-appl-psvc-nonprod-rg"
  }
}

# TODO: object ID of the pipeline's service principal (az ad sp show --id <client id> --query id -o tsv).
# It gets Grafana Admin so the content stage can deploy dashboards.
# deployment_principal_object_id = "00000000-0000-0000-0000-000000000000"

# TODO: Entra ID group object IDs.
grafana_access = {
  # platform_admins = { principal_id = "00000000-0000-0000-0000-000000000000", role = "Grafana Admin" }
  # pushservice_dev = { principal_id = "00000000-0000-0000-0000-000000000000", role = "Grafana Editor" }
  # readers         = { principal_id = "00000000-0000-0000-0000-000000000000", role = "Grafana Viewer" }
}

tags = {
  environment = "nonprod"
  project     = "pushservice"
}
