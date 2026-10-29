variable "grafana_name" {
  type        = string
  description = "The name of the Azure Managed Grafana workspace."
  nullable    = false
}

variable "location" {
  type        = string
  description = "Azure region of the Grafana workspace. When importing an existing workspace it must match its current region."
  nullable    = false
}

variable "resource_group_name" {
  type        = string
  description = "The existing resource group that holds the Grafana workspace."
  nullable    = false
}

variable "azure_monitor_workspaces" {
  type = map(object({
    name                = string
    resource_group_name = string
    subscription_id     = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
Azure Monitor workspaces (managed Prometheus) to link to Grafana. Linking creates a Prometheus data source in Grafana.
For queries to work, the workspace's owner must grant Grafana's identity (output `grafana_principal_id`) `Monitoring Data Reader`.
This stack doesn't create that assignment.

- `subscription_id` - (Optional) Defaults to the subscription Terraform runs in.
DESCRIPTION
  nullable    = false
}

variable "api_key_enabled" {
  type        = bool
  default     = false
  description = "Enable Grafana API keys and service accounts. When importing an existing workspace, match its current setting: disabling it invalidates existing service account tokens."
  nullable    = false
}

variable "deployment_principal_object_id" {
  type        = string
  default     = null
  description = "Object ID of the pipeline service principal that deploys stacks/02-content. It gets `Grafana Admin` on the workspace. Leave `null` to grant nothing."

  validation {
    condition     = var.deployment_principal_object_id == null || can(regex("^[0-9a-fA-F]{8}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{4}-[0-9a-fA-F]{12}$", var.deployment_principal_object_id))
    error_message = "deployment_principal_object_id must be an Entra object ID (GUID)."
  }
}

variable "deterministic_outbound_ip_enabled" {
  type        = bool
  default     = false
  description = "Use deterministic outbound IPs. When importing an existing workspace, match its current setting: changing it changes the IPs that firewalls may allow-list."
  nullable    = false
}

variable "enable_telemetry" {
  type        = bool
  default     = false
  description = <<DESCRIPTION
Enable AVM telemetry. Off by default here for two reasons. It deploys ARM deployments at subscription scope, which needs
`Microsoft.Resources/deployments/write` on the subscription. Its timestamp also changes on every plan, so plans would never
report "no changes".
DESCRIPTION
  nullable    = false
}

variable "external_snapshots_enabled" {
  type        = bool
  default     = false
  description = "Allow publishing dashboard snapshots to an external snapshot server. Off by default, as the Azure Managed Grafana security guidance recommends; note that the service default for an existing workspace is on, so the first plan of an imported workspace turns it off unless you set `true`."
  nullable    = false
}

variable "grafana_access" {
  type = map(object({
    principal_id   = string
    principal_type = optional(string, "Group")
    role           = string
  }))
  default     = {}
  description = <<DESCRIPTION
Who can sign in to Grafana and with which role. Prefer Entra ID groups.

- `principal_id` - Object ID of the user, group or service principal.
- `principal_type` - (Optional) `Group`, `User` or `ServicePrincipal`. Defaults to `Group`.
- `role` - `Grafana Admin`, `Grafana Editor`, `Grafana Viewer` or `Grafana Limited Viewer`.
DESCRIPTION
  nullable    = false

  validation {
    condition     = alltrue([for v in var.grafana_access : contains(["Grafana Admin", "Grafana Editor", "Grafana Viewer", "Grafana Limited Viewer"], v.role)])
    error_message = "`role` must be one of: Grafana Admin, Grafana Editor, Grafana Viewer, Grafana Limited Viewer."
  }
}

variable "grafana_major_version" {
  type        = string
  default     = "12"
  description = "The major Grafana version."
  nullable    = false
}

variable "import_existing_grafana" {
  type        = bool
  default     = false
  description = "Import a Grafana workspace that already exists under `grafana_name` instead of creating it. Review the first plan carefully: it shows every setting Terraform will change on the existing workspace."
  nullable    = false
}

variable "lock_kind" {
  type        = string
  default     = null
  description = "Optional resource lock on the workspace: `CanNotDelete` (recommended for production) or `ReadOnly`, which also blocks updates."
}

variable "log_analytics_workspace_resource_id" {
  type        = string
  default     = null
  description = "Optional Log Analytics workspace that receives the Grafana login and usage logs."
}

variable "private_endpoints" {
  type = map(object({
    subnet_resource_id            = string
    private_dns_zone_resource_ids = optional(set(string), [])
    name                          = optional(string, null)
  }))
  default     = {}
  description = <<DESCRIPTION
Private endpoints through which users reach Grafana, keyed by an arbitrary name. With at least one, public network
access is disabled unless `public_network_access_enabled` says otherwise.

- `subnet_resource_id` - The subnet of the private endpoint.
- `private_dns_zone_resource_ids` - (Optional) `privatelink.grafana.azure.com` zones to register the endpoint in. Leave
  empty when DNS records are managed centrally, e.g. by Azure Policy.
- `name` - (Optional) Defaults to `pep-<workspace>-<key>`.
DESCRIPTION
  nullable    = false
}

variable "public_network_access_enabled" {
  type        = bool
  default     = null
  description = "Allow access to Grafana over the public network. `null` (default) disables it when `private_endpoints` is not empty and keeps it enabled otherwise. When importing an existing workspace, match its current setting."
}

variable "sku_size" {
  type        = string
  default     = "X1"
  description = "Standard tier instance size, `X1` or `X2`."
  nullable    = false
}

variable "tags" {
  type        = map(string)
  default     = null
  description = "Tags applied to the Grafana workspace."
}

variable "zone_redundancy_enabled" {
  type        = bool
  default     = false
  description = "Enable zone redundancy: recommended for production where the region supports it (see \"Reliability in Azure Managed Grafana\" on Microsoft Learn). Create-time only: changing it replaces the workspace and every dashboard in it. Extra cost."
  nullable    = false
}
