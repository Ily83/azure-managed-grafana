grafana_name        = "axso4np4nonp4psvc4amg"
resource_group_name = "axso-np-appl-psvc-nonprod-rg"

# Keys are the sub-directories of dashboards/. Folders without an entry are still created, titled after the directory.
folders = {
  aks              = { title = "Azure - AKS" }
  app-service      = { title = "Azure - App Service" }
  operations       = { title = "Azure - Operations" }
  postgresql       = { title = "Azure - PostgreSQL" }
  redis            = { title = "Azure - Redis" }
  virtual-machines = { title = "Azure - Virtual Machines" }
  # To make a folder's permissions authoritative (replaces Grafana's defaults on that folder), add for example:
  #   permissions = [{ role = "Viewer", permission = "View" }, { role = "Editor", permission = "Edit" }]
}
