# azure-managed-grafana

Azure Managed Grafana and its dashboards, as code.

```
stacks/01-platform  ──(azapi)──────▶  Azure Managed Grafana workspace (Standard)
  └ avm-res-dashboard-grafana (fork)     ├ RBAC on the workspace: Grafana Admin/Editor/Viewer for groups and the pipeline
                                         ├ system-assigned identity (output: grafana_principal_id)
                                         └ linked Azure Monitor workspaces, diagnostics, lock

stacks/02-content   ──(grafana)────▶  inside Grafana: folders, permissions, data sources, dashboards
  └ modules/grafana-content          ◀── dashboards/<folder>/<dashboard>.json[.tftpl]

other services' own AVM code ──────▶  role_assignments granting grafana_principal_id read access to their data
```

## Layout

| Path | What |
| --- | --- |
| `modules/grafana-content` | Folders, data sources and dashboards through the Grafana API. See its [README](modules/grafana-content/README.md). |
| `stacks/01-platform` | Root module: creates (or adopts) the workspace. One state per environment. |
| `stacks/02-content` | Root module: deploys `dashboards/`. One state per environment. |
| `dashboards/` | Dashboard JSON, one sub-directory per Grafana folder. |
| `pipelines/` | Azure DevOps pipeline. Runs validate, then plan → approval → apply for each stack in turn. |

### The Grafana workspace module

The workspace module isn't in this folder. It's an AVM resource module built on the official repo
[`Azure/terraform-azurerm-avm-res-dashboard-grafana`](https://github.com/Azure/terraform-azurerm-avm-res-dashboard-grafana),
which has no release yet. `stacks/01-platform` takes it from the fork
[`Ily83/terraform-azurerm-avm-res-dashboard-grafana`](https://github.com/Ily83/terraform-azurerm-avm-res-dashboard-grafana),
pinned to commit `66e0917` (branch `feat/azapi-grafana-avm-checks`). It was tested against Azure on 2026-10-29 (create,
second plan with no changes, destroy), and its unit tests run in that repository. It passes `avm pre-commit`,
`avm lint` and `avm pr-check` (which includes `avm check policy`).

- **Changing the module:** work in a clone of the fork, push, then update the commit in the `source` of
  `stacks/01-platform/main.tf`.
- **CI:** `terraform init` downloads the module from github.com, so the build agents need outbound access to it. For
  production, consider mirroring the fork into Azure Repos, or switching to the registry release once Azure publishes one.

### Why two stacks

The Grafana provider needs the workspace URL and a token before it can plan anything. With a single state, the first
plan of a new environment fails. Splitting the work also means dashboard changes never touch the Azure resource.
`02-content` finds the workspace by name, so it also works against a workspace created by hand.

### Ownership boundaries

This solution manages **only Grafana**: the workspace, the role assignments *on* it, its diagnostics and lock, and its contents.
It never writes into another service's scope. Grafana's identity needs read access to the data it shows, which the code
owning each service grants through that service's AVM `role_assignments` input, using the `grafana_principal_id` output:

| Service | Role for Grafana's identity | Scope |
| --- | --- | --- |
| Azure Monitor workspace (managed Prometheus) | Monitoring Data Reader | the workspace |
| PostgreSQL, Redis, VMs, App Service, AKS (Azure Monitor metrics) | Monitoring Reader | the resource or its resource group |

```hcl
# In the code that owns e.g. the PostgreSQL server:
module "postgresql" {
  source = "Azure/avm-res-dbforpostgresql-flexibleserver/azurerm"
  # ...
  role_assignments = {
    grafana = {
      role_definition_id_or_name = "Monitoring Reader"
      principal_id               = "<grafana_principal_id output of stacks/01-platform>"
      principal_type             = "ServicePrincipal"
    }
  }
}
```

If no code manages a resource, grant the role once by hand or through your landing-zone RBAC, e.g. Monitoring Reader at subscription or
management-group level.

## Authentication

No API keys or service accounts. Everything uses Microsoft Entra ID:

- **Azure (azapi, state backend):** the Azure CLI login of the `AzureCLI@2` task (service connection) or your `az login`.
- **Grafana API:** an Entra access token for the Managed Grafana audience, passed in `GRAFANA_AUTH`:
  ```bash
  export GRAFANA_AUTH=$(az account get-access-token --resource https://dashboard.azure.com --query accessToken -o tsv)
  ```
  The pipeline identity needs **Grafana Admin** on the workspace. `01-platform` grants it to `deployment_principal_object_id`.
  The ID is set explicitly so that a local `terraform apply` doesn't move the grant from the pipeline to you.

### Permissions for the pipeline service principal

| Scope | Role | For |
| --- | --- | --- |
| Grafana resource group | Contributor | Create/update the workspace, diagnostic settings, lock |
| Grafana workspace (or its resource group) | Role Based Access Control Administrator | Grafana Admin/Editor/Viewer assignments on the workspace |
| State container | Storage Blob Data Contributor | Terraform state |

AVM telemetry is off (`enable_telemetry = false`). It needs subscription-level `deployments/write`, and it changes every plan.

## First run in nonprod

The nonprod workspace `axso4np4nonp4psvc4amg` already exists, so `01-platform` **imports** it (`import_existing_grafana = true`).

1. Fill in the TODOs:
   - `stacks/01-platform/env/nonprod.tfvars`: `deployment_principal_object_id`, and the Entra group IDs in `grafana_access`.
   - `pipelines/variables/grafana-variables-nonprod.yml`: `azure_service_connection`.
2. Copy the workspace's current settings into the tfvars, using the `az grafana show` command there. A different **location**
   or **zone redundancy** would *replace* the workspace and delete all its dashboards. The pipeline refuses any plan
   that deletes or replaces resources unless the run is queued with `allowDestroy = true`. The same command shows public
   network access and external snapshots: the module turns external snapshots off by default (the service default is on),
   so set `external_snapshots_enabled = true` if the workspace needs them.
3. Make sure the owners of the Azure Monitor workspace and the monitored resources have granted Grafana's identity its roles (see *Ownership boundaries*).
   If the workspace was linked in the portal before, Microsoft may already have granted Monitoring Data Reader.
4. Create the Azure DevOps environment `grafana-nonprod` with an approval check, then run the pipeline. You approve each
   apply stage **after** reading the plan of the previous stage. If the workspace is still on the deprecated **Essential**
   tier, the plan upgrades it to **Standard**, which costs more.
5. If dashboards or folders were already created by hand, the content apply takes over dashboards with the same UID
   (`dashboard_overwrite = true`). A hand-made folder with the same title may conflict. Import it, or delete it in the UI first:
   `terraform import 'module.content.grafana_folder.this["<sub-directory>"]' <folder-uid>`.

## Run locally

```bash
az login
export GRAFANA_AUTH=$(az account get-access-token --resource https://dashboard.azure.com --query accessToken -o tsv)
cd stacks/02-content
terraform init -backend-config=storage_account_name=axso4prod4appl4tim4sa \
               -backend-config=container_name=terraform-irix-modules \
               -backend-config="key=<repo>/irix_grafana_content_pushservice_nonprod.tfstate"
terraform plan -var-file=env/nonprod.tfvars
```

Without a backend (syntax checks only): `terraform init -backend=false && terraform validate`.

## Dashboards

Where a good dashboard already existed, ours builds on it or links to it rather than duplicating it.

| Folder | Dashboards | Data source | Built on |
| --- | --- | --- | --- |
| `operations` | Operations overview | Resource Graph | New, for operators, across all covered services: what needs attention now (resource state, open alerts, Resource Health, Azure service health), what changed and who changed it, Advisor recommendations. Links to each service dashboard and to the bundled *Azure / Alert Consumption* |
| `postgresql` | PostgreSQL flexible server overview | Azure Monitor metrics + Resource Graph | Grafana's bundled *Azure / Azure PostgreSQL / Flexible Server Monitoring* (v12.4, AGPL-3.0). Fixes six wrong metrics or aggregations and three wrong units; adds inventory, replication and disk panels |
| `redis` | Azure Managed Redis overview, Azure Cache for Redis overview | Azure Monitor metrics + Resource Graph | Managed Redis: Microsoft's grafana.com dashboard 24988, with aggregations corrected. Cache for Redis: new, since no official one exists |
| `aks` | Cluster landing page (Prometheus) and a platform-metrics dashboard | Managed Prometheus; Azure Monitor metrics | The landing page links to the **built-in** *Managed Prometheus* dashboards (from `Azure/prometheus-collector`) that Azure Managed Grafana installs when an Azure Monitor workspace is linked, under its own uids (ending in `6738`). Those are not copied here |
| `virtual-machines` | VM overview | Azure Monitor metrics + Resource Graph | New. Links to the bundled *VM Insights* / *Compute Monitoring* dashboards |
| `app-service` | Web app + App Service plan overview | Azure Monitor metrics + Resource Graph | New. Links to the bundled *Apps Monitoring* fleet dashboard |

Every service dashboard starts with a **Troubleshooting** row for the selected resource: its state, open alerts, and the
Resource Manager changes in the time range (who, with which operation, which properties). The dashboard links open the
resource in the Azure portal, its *Diagnose and solve problems* page, and the operations overview.

**Verified on Azure** on 2026-10-29: Azure Managed Grafana 12.4.13 in Switzerland North, against a PostgreSQL flexible server,
Azure Managed Redis, a VM, a Linux web app and an AKS cluster with managed Prometheus:
- Both stacks apply, and a second plan shows no changes for either of them.
- Every panel query, run through the Grafana API, is accepted by Azure, except the cases under *Caveats*. Panels that stayed
  empty need something the test didn't have (read replicas, PgBouncer, Redis high availability, data disks, B-series VMs,
  health checks, the cluster autoscaler), or only fill when something goes wrong (pod restarts, HTTP 5xx).
- Locally, on Grafana 12.4 and 13.2 containers: edits update in place, removing a file deletes its dashboard, and folder
  permissions apply.

Expect to tune thresholds after the first deploy.

Caveats:
- **PostgreSQL:** some panels stay empty unless server parameters are on.
  - Enhanced metrics need `metrics.collector_database_activity`.
  - Autovacuum metrics need `metrics.autovacuum_diagnostics`.
  - PgBouncer metrics need `pgbouncer.enabled` plus `metrics.pgbouncer_diagnostics`.
- **AKS:** the drill-down links work only if Azure Managed Grafana has installed its *Managed Prometheus* dashboards.
- **Grafana 13:** Prometheus dashboards then use the `grafana-azureprometheus-datasource` plugin. The content stack switches automatically; Azure Managed Grafana 13 ships the plugin.
- **Redis:** Azure Cache for Redis is being retired. The Enterprise tiers retire on 31 March 2027, and Basic, Standard and Premium on 30 September 2028. Microsoft recommends Azure Managed Redis.
  Azure already refuses new instances ("Azure Cache for Redis is retiring, create Azure Managed Redis instance instead"), so the *Cache for Redis* dashboard is for existing caches and wasn't tested against a live one.
- **App Service:** the process counters (application queue, private bytes, connections, threads, handles) exist only for Windows apps. They sit in the collapsed *Windows apps only* row; on a Linux app, expanding it shows errors.
- **Operations:** Azure service health events are subscription-wide, so Grafana's identity sees them only with read access on
  the subscription. Resource Health in Resource Graph covers few resource types (mainly VMs); the state columns come from
  Resource Manager and cover all of them. Change history is kept 14 days, alerts 30 days.
- **VM:** the link to *VM Insights* (`/d/AzVmInsightsByRG`) needs that bundled dashboard to be imported.

## Add a dashboard

1. Build it in Grafana, then export it with **Export → Export as JSON**.
2. Save it as `dashboards/<folder>/<name>.json` (or `.json.tftpl` if it needs per-environment values).
3. Use a `datasource` template variable instead of fixed data source UIDs (see `dashboards/aks/aks-cluster-prometheus.json.tftpl`).
   Every dashboard UID must be unique. The plan fails and names the files if two collide.
4. Open a PR. The pipeline validates and plans it, and it is applied after approval.

Edits made in the Grafana UI are overwritten on the next apply. Export them back to the repo first.

## Add an environment (e.g. prod)

Copy `env/nonprod.tfvars` to `env/prod.tfvars` in both stacks, plus `pipelines/variables/grafana-variables-prod.yml` and
`pipelines/azure-pipeline-prod.yml`. The templates are parameterised.

Each environment chooses these in its `stacks/01-platform/env/<env>.tfvars`:

| Option | Default | Production advice |
| --- | --- | --- |
| `zone_redundancy_enabled` | `false` | `true` where the region supports it. Create-time only: changing it later replaces the workspace and its dashboards. |
| `private_endpoints` | none | Reach Grafana through a private endpoint in the hub or spoke network. |
| `public_network_access_enabled` | automatic: off with a private endpoint, on without | Leave automatic, or set it to match your Azure Policy. |
| `lock_kind` | none | `CanNotDelete`. `ReadOnly` also blocks updates. |
| `external_snapshots_enabled` | `false` | Keep `false`. |
| `log_analytics_workspace_resource_id` | none | Send login and usage logs to the central workspace. |
| `sku_size` | `X1` | `X2` for more than 500 alert rules per organisation. It can't be lowered again. |

In the content stack, consider folder `permissions` for prod.

Azure has no backup of dashboards, so they are only as safe as this repository. For a regional outage, deploy a second
environment in another region from the same code.

## Tests

These run locally with mocked providers, and in the pipeline's validate stage. The workspace module's tests (22, plus 4
for its private-endpoint submodule) run in the module's own repository.

```bash
(cd modules/grafana-content && terraform init && terraform test -test-directory=tests/unit)  # 5
(cd stacks/02-content && terraform init -backend=false && terraform test)                     # renders every file in dashboards/
(cd stacks/01-platform && terraform init -backend=false && terraform validate)                # downloads the pinned module
```
