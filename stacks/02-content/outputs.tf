output "dashboards" {
  description = "The dashboards deployed, with their UID and URL."
  value       = module.content.dashboards
}

output "folders" {
  description = "The folders deployed, with their UID and URL."
  value       = module.content.folders
}

output "grafana_endpoint" {
  description = "The URL of the Grafana workspace."
  value       = data.azapi_resource.grafana.output.properties.endpoint
}
