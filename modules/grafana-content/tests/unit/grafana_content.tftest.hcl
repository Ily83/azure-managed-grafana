mock_provider "grafana" {}

variables {
  dashboards_directory = "./tests/unit/fixtures/dashboards"
  dashboard_template_variables = {
    prometheus_uid = "amw-prometheus"
  }
}

run "dashboards_and_folders_from_directory" {
  command = apply

  assert {
    condition     = toset(keys(grafana_folder.this)) == toset(["team-a", "team-b"])
    error_message = "Each dashboard sub-directory must become a folder."
  }
  assert {
    condition     = grafana_folder.this["team-a"].title == "team-a" && grafana_folder.this["team-a"].uid == "team-a"
    error_message = "Folder title and UID must default to the directory name."
  }
  assert {
    condition     = toset(keys(grafana_dashboard.this)) == toset(["team-a/service-overview", "team-b/latency"])
    error_message = "Both .json and .json.tftpl dashboards must be discovered."
  }
  assert {
    condition     = !can(jsondecode(grafana_dashboard.this["team-a/service-overview"].config_json).id)
    error_message = "The instance-specific numeric id must be stripped from exported dashboards."
  }
  assert {
    condition     = jsondecode(grafana_dashboard.this["team-a/service-overview"].config_json).uid == "team-a-service-overview"
    error_message = "A missing uid must be derived from the file path."
  }
  assert {
    condition     = jsondecode(grafana_dashboard.this["team-b/latency"].config_json).uid == "team-b-latency"
    error_message = "An explicit uid in the dashboard JSON must be kept."
  }
  assert {
    condition     = jsondecode(grafana_dashboard.this["team-b/latency"].config_json).panels[0].datasource.uid == "amw-prometheus"
    error_message = "Template variables must be rendered into .json.tftpl dashboards."
  }
  assert {
    condition     = jsondecode(grafana_dashboard.this["team-b/latency"].config_json).panels[0].targets[0].legendFormat == "$${instance}"
    error_message = "Escaped Grafana variables must survive templating."
  }
  assert {
    condition     = grafana_dashboard.this["team-b/latency"].folder == grafana_folder.this["team-b"].uid
    error_message = "Dashboards must be placed in the folder matching their directory."
  }
  assert {
    condition     = length(grafana_folder_permission.this) == 0
    error_message = "Folder permissions must stay unmanaged unless configured."
  }
}

run "folder_overrides_and_permissions" {
  command = apply

  variables {
    folders = {
      team-a = {
        title = "Team A"
        permissions = [
          { role = "Viewer", permission = "View" },
          { role = "Editor", permission = "Edit" },
        ]
      }
      empty = {
        title = "Empty folder"
        uid   = "empty-folder"
      }
    }
  }

  assert {
    condition     = grafana_folder.this["team-a"].title == "Team A"
    error_message = "`folders` must override the title of a discovered folder."
  }
  assert {
    condition     = grafana_folder.this["empty"].uid == "empty-folder"
    error_message = "Folders without dashboards must still be created."
  }
  assert {
    condition     = length(grafana_folder_permission.this["team-a"].permissions) == 2
    error_message = "Configured folder permissions must be applied."
  }
}

run "data_sources" {
  command = apply

  variables {
    data_sources = {
      prometheus = {
        name = "Managed Prometheus"
        type = "prometheus"
        uid  = "amw-prometheus"
        url  = "https://amw-test.westeurope.prometheus.monitor.azure.com"
        json_data_encoded = jsonencode({
          httpMethod       = "POST"
          azureCredentials = { authType = "msi" }
        })
      }
    }
  }

  assert {
    condition     = grafana_data_source.this["prometheus"].uid == "amw-prometheus"
    error_message = "The data source must keep its explicit uid."
  }
  assert {
    condition     = grafana_data_source.this["prometheus"].secure_json_data_encoded == null
    error_message = "No secure data must be sent unless configured."
  }
}

run "invalid_folder_permission" {
  command = plan

  variables {
    folders = {
      team-a = {
        title       = "Team A"
        permissions = [{ role = "Viewer", team_id = "1", permission = "View" }]
      }
    }
  }

  expect_failures = [var.folders]
}

run "duplicate_dashboard_uid" {
  command = plan

  variables {
    dashboards_directory = "./tests/unit/fixtures/dashboards-duplicate-uid"
  }

  expect_failures = [grafana_dashboard.this]
}
