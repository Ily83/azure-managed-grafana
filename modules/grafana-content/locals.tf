locals {
  # Dashboards are discovered from <dashboards_directory>/<folder key>/<name>.json[.tftpl].
  dashboard_files = var.dashboards_directory == null ? [] : fileset(var.dashboards_directory, "*/*.{json,json.tftpl}")
  # Exported dashboards carry an instance-specific numeric `id` that must not be pushed to another instance.
  # A missing `uid` is derived from the file path, so dashboard URLs stay stable across applies and environments.
  dashboard_json = {
    for k, v in local.dashboards : k => merge(
      { for attr, value in v.content : attr => value if attr != "id" },
      { uid = try(coalesce(v.content.uid), substr(replace(lower(k), "/[^a-z0-9_-]/", "-"), 0, 40)) },
    )
  }
  dashboards = {
    for f in local.dashboard_files : trimsuffix(trimsuffix(f, ".tftpl"), ".json") => {
      folder_key = dirname(f)
      content = jsondecode(
        endswith(f, ".tftpl") ?
        templatefile("${var.dashboards_directory}/${f}", var.dashboard_template_variables) :
        file("${var.dashboards_directory}/${f}")
      )
    }
  }
  # Every sub-directory of `dashboards_directory` becomes a folder; `var.folders` overrides title, uid and permissions.
  folders = {
    for k in setunion(keys(var.folders), [for d in values(local.dashboards) : d.folder_key]) : k => {
      title                        = try(var.folders[k].title, k)
      uid                          = try(coalesce(var.folders[k].uid), substr(replace(lower(k), "/[^a-z0-9_-]/", "-"), 0, 40))
      permissions                  = try(var.folders[k].permissions, null)
      prevent_destroy_if_not_empty = try(var.folders[k].prevent_destroy_if_not_empty, true)
    }
  }
}
