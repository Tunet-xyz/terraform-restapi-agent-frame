terraform {
  required_version = ">= 1.10.0, < 2.0.0"
}

locals {
  catalog = jsondecode(file("${path.module}/../../backends.json"))
}

output "backends" {
  description = "Reviewed capabilities and entry points. A null module means native-provider coverage only, not an adapter shipped here."
  value       = local.catalog.backends
}
output "reviewed_on" {
  value = local.catalog.reviewed_on
}

output "inference_profiles" {
  description = "Reviewed inference endpoints for modules/inference. These export definitions and never create remote agents."
  value       = jsondecode(file("${path.module}/../inference/profiles.json")).profiles
}
