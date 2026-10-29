resource "grafana_folder" "this" {
  for_each = local.folders

  title                        = each.value.title
  prevent_destroy_if_not_empty = each.value.prevent_destroy_if_not_empty
  uid                          = each.value.uid
}

# Authoritative: replaces every permission on the folder, including the defaults Grafana adds.
resource "grafana_folder_permission" "this" {
  for_each = { for k, v in local.folders : k => v if v.permissions != null }

  folder_uid = grafana_folder.this[each.key].uid

  dynamic "permissions" {
    for_each = each.value.permissions

    content {
      permission = permissions.value.permission
      role       = permissions.value.role
      team_id    = permissions.value.team_id
      user_id    = permissions.value.user_id
    }
  }
}

resource "grafana_data_source" "this" {
  for_each = var.data_sources

  name                     = each.value.name
  type                     = each.value.type
  access_mode              = each.value.access_mode
  is_default               = each.value.is_default
  json_data_encoded        = each.value.json_data_encoded
  secure_json_data_encoded = contains(keys(var.data_source_secure_json_data), each.key) ? jsonencode(var.data_source_secure_json_data[each.key]) : null
  uid                      = each.value.uid
  url                      = each.value.url
}

resource "grafana_dashboard" "this" {
  for_each = local.dashboards

  config_json = jsonencode(local.dashboard_json[each.key])
  folder      = grafana_folder.this[each.value.folder_key].uid
  message     = var.dashboard_commit_message
  overwrite   = var.dashboard_overwrite

  # Dashboards reference data sources by UID, so create those first.
  depends_on = [grafana_data_source.this]

  lifecycle {
    # Two files with the same UID would silently overwrite each other on every apply.
    precondition {
      condition     = length(distinct([for d in values(local.dashboard_json) : d.uid])) == length(local.dashboard_json)
      error_message = "Dashboard UIDs must be unique across all dashboard files. Duplicates: ${join(", ", [for uid, files in { for k, d in local.dashboard_json : d.uid => k... } : "${uid} (${join(", ", files)})" if length(files) > 1])}."
    }
  }
}
