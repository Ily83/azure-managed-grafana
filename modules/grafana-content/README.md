# grafana-content

Manages what lives **inside** a Grafana instance: folders, folder permissions, data sources and dashboards.
It uses the [`grafana/grafana`](https://registry.terraform.io/providers/grafana/grafana/latest/docs) provider, which the caller configures.
This module is not an AVM module: AVM only covers Azure Resource Manager resources.

## Dashboards as files

```
dashboards/
├── databases/                        -> folder "databases"
│   ├── overview.json                 -> uploaded as-is
│   └── latency.json.tftpl            -> rendered with templatefile(dashboard_template_variables)
└── platform/
    └── aks.json
```

- Each sub-directory becomes a folder. Set its title, UID or permissions with `folders`.
- `id` is stripped from the JSON. A missing `uid` is derived from the path (`databases-overview`), so URLs stay stable across applies and environments.
- UIDs must be unique across all files. The plan fails and names the colliding files.
- To add a dashboard: build it in the Grafana UI, use **Export → Export as JSON**, drop the file into the folder, and open a PR.
- In `.json.tftpl` files, Grafana variables written with braces must be escaped: `$${instance}`. Brace-less forms such as `$job` and `$__rate_interval` need no escaping.
- Prefer a `datasource`-type template variable (`"uid": "$datasource"`) over hard-coded data source UIDs. The dashboard then works with whichever data source exists in each environment.

## Usage

```hcl
provider "grafana" {
  url = "https://<workspace>.grafana.azure.com"   # auth from GRAFANA_AUTH (Entra token or service account token)
}

module "content" {
  source = "../../modules/grafana-content"

  dashboards_directory         = "${path.module}/dashboards"
  dashboard_template_variables = { prometheus_datasource_type = "prometheus" }

  folders = {
    databases = {
      title       = "Databases"
      permissions = [{ role = "Viewer", permission = "View" }, { role = "Editor", permission = "Edit" }]
    }
  }

  data_sources = {
    adx = {
      name              = "Azure Data Explorer"
      type              = "grafana-azure-data-explorer-datasource"
      uid               = "adx"
      json_data_encoded = jsonencode({ clusterUrl = "https://<cluster>.kusto.windows.net", azureCredentials = { authType = "msi" } })
    }
  }
}
```

## Inputs

| Name | Default | Description |
| --- | --- | --- |
| `dashboards_directory` | `null` | Root directory of `<folder>/<dashboard>.json[.tftpl]` files. |
| `dashboard_template_variables` | `{}` | Variables for `.json.tftpl` dashboards. |
| `folders` | `{}` | Folder title/UID overrides and authoritative permissions (`null` = unmanaged). |
| `data_sources` | `{}` | Extra data sources. Use explicit `uid`s. |
| `data_source_secure_json_data` | `{}` | Sensitive per-data-source secrets. |
| `dashboard_overwrite` | `true` | Take over dashboards that already exist with the same UID. |
| `dashboard_commit_message` | `Managed by Terraform` | Message stored in the dashboard version history. |

## Outputs

`dashboards` (uid, url), `folders` (uid, url), `data_source_uids`.

## Tests

```bash
terraform init
terraform test -test-directory=tests/unit
```
