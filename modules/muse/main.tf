terraform {
  required_version = ">= 1.10.0, < 2.0.0"
}

module "inference" {
  source = "../inference"

  profile      = "muse"
  name         = var.name
  model        = var.model
  instructions = var.instructions
  metadata     = var.metadata
  options      = var.options
}

output "agent" {
  value = module.inference.agent
}
output "definition" {
  value = module.inference.definition
}
output "fingerprint" {
  value = module.inference.fingerprint
}
output "runtime_fingerprint" {
  value = module.inference.runtime_fingerprint
}
output "capabilities" {
  value = module.inference.capabilities
}
output "runtime" {
  value = module.inference.runtime
}
