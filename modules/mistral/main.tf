terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 2.0.1"
    }
  }
}

module "definition" {
  source = "../definition"

  vendor       = "mistral"
  name         = var.name
  model        = var.model
  instructions = var.instructions
  metadata     = var.metadata
  tools_json   = var.options.tools_json
}

module "backend" {
  source    = "../rest"
  providers = { restapi = restapi }

  vendor = "mistral"
  name   = var.name
  model  = var.model
  endpoint = {
    path          = "/agents"
    update_method = "PATCH"
    ignore_changes_to = [
      "id", "object", "created_at", "updated_at", "version", "versions",
      "owner_id", "deployment_chat", "source", "version_message",
      "completion_args", "guardrails", "handoffs",
    ]
  }
  payload_json = jsonencode({
    name         = module.definition.definition.name
    model        = module.definition.definition.model
    instructions = module.definition.definition.instructions
    metadata     = module.definition.definition.metadata
    tools        = module.definition.definition.tools
    description  = var.options.description
  })
}

output "agent" {
  value = module.backend.agent
}

output "definition" {
  value = module.definition.definition
}

output "capabilities" {
  value = { management = "remote_agent", remote_lifecycle = true }
}
