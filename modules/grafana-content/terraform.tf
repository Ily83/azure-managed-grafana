terraform {
  required_version = ">= 1.9, < 2.0"

  required_providers {
    grafana = {
      source  = "grafana/grafana"
      version = ">= 4.0, < 5.0"
    }
  }
}
