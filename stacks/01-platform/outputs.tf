output "grafana_endpoint" {
  description = "The URL of the Grafana workspace."
  value       = module.grafana.endpoint
}

output "grafana_principal_id" {
  description = <<DESCRIPTION
The principal ID of Grafana's system-assigned identity. The code that owns each monitored service grants it access through
that service's AVM `role_assignments` input: `Monitoring Data Reader` on Azure Monitor workspaces, `Monitoring Reader` on resources.
DESCRIPTION
  value       = module.grafana.system_assigned_mi_principal_id
}

output "grafana_resource_id" {
  description = "The resource ID of the Grafana workspace."
  value       = module.grafana.resource_id
}
