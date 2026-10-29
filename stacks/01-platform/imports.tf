# Adopts a workspace that was created outside Terraform (e.g. in the portal) on the first apply.
# Once the workspace is in state the import is a no-op, so the flag can stay on.
import {
  for_each = var.import_existing_grafana ? toset([var.grafana_name]) : toset([])

  id = "${local.resource_group_resource_id}/providers/Microsoft.Dashboard/grafana/${each.value}?api-version=2025-08-01"
  to = module.grafana.azapi_resource.this
}
