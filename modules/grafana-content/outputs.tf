output "dashboards" {
  description = "A map of the dashboards created (keyed by `<folder key>/<file name>`), with their UID and URL."
  value = {
    for k, v in grafana_dashboard.this : k => {
      uid = v.uid
      # Without the title slug, so renaming a dashboard doesn't change the output (Grafana resolves /d/<uid>).
      url = try(regex("^(.*/d/[^/]+)", v.url)[0], v.url)
    }
  }
}

output "data_source_uids" {
  description = "A map of the data sources created to their UIDs."
  value       = { for k, v in grafana_data_source.this : k => v.uid }
}

output "folders" {
  description = "A map of the folders created, with their UID and URL."
  value = {
    for k, v in grafana_folder.this : k => {
      uid = v.uid
      url = v.url
    }
  }
}
