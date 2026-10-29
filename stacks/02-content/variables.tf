variable "grafana_name" {
  type        = string
  description = "The name of the existing Azure Managed Grafana workspace (created by stacks/01-platform or by hand)."
  nullable    = false
}

variable "resource_group_name" {
  type        = string
  description = "The resource group of the Grafana workspace."
  nullable    = false
}

variable "dashboard_template_variables" {
  type        = map(string)
  default     = {}
  description = "Extra variables for `*.json.tftpl` dashboards, e.g. resource IDs that differ per environment. `prometheus_datasource_type` and `grafana_major_version` are provided automatically."
  nullable    = false
}

variable "data_sources" {
  type = map(object({
    name              = string
    type              = string
    uid               = optional(string, null)
    url               = optional(string, null)
    access_mode       = optional(string, "proxy")
    is_default        = optional(bool, false)
    json_data_encoded = optional(string, null)
  }))
  default     = {}
  description = "Additional Grafana data sources. Linked Azure Monitor workspaces and the built-in Azure Monitor data source need no entry here."
  nullable    = false
}

variable "folders" {
  type = map(object({
    title = string
    uid   = optional(string, null)
    permissions = optional(list(object({
      permission = string
      role       = optional(string, null)
      team_id    = optional(string, null)
      user_id    = optional(string, null)
    })), null)
    prevent_destroy_if_not_empty = optional(bool, true)
  }))
  default     = {}
  description = "Folder titles, UIDs and permissions, keyed by the dashboard sub-directory name. See modules/grafana-content."
  nullable    = false
}
