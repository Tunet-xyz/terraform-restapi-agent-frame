terraform {
  required_version = ">= 1.10.0, < 2.0.0"
}

locals {
  definition = {
    schema_version = 1
    vendor         = var.vendor
    name           = var.name
    model          = var.model
    instructions   = var.instructions
    metadata       = var.metadata
    tools          = jsondecode(var.tools_json)
    settings       = jsondecode(var.settings_json)
  }
}

output "definition" {
  description = "Portable configuration, independent of any hosted agent resource. Credentials belong in the runtime environment."
  value       = local.definition
}

output "definition_json" {
  value = jsonencode(local.definition)
}

output "fingerprint" {
  description = "Content fingerprint for deployment triggers; this is not a remote agent ID."
  value       = sha256(jsonencode(local.definition))
}

output "agent" {
  description = "Common handle. A definition has no remote ID or lifecycle."
  value = {
    id       = null
    vendor   = var.vendor
    name     = var.name
    model    = var.model
    version  = null
    archived = false
  }
}
