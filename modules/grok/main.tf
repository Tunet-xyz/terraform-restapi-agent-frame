terraform {
  required_version = ">= 1.10.0, < 2.0.0"
}

module "definition" {
  source = "../definition"

  vendor        = "xai"
  name          = var.name
  model         = var.model
  instructions  = var.instructions
  metadata      = var.metadata
  tools_json    = var.options.tools_json
  settings_json = var.options.settings_json
}

output "agent" {
  value = module.definition.agent
}

output "definition" {
  value = module.definition.definition
}

output "fingerprint" {
  value = module.definition.fingerprint
}

output "capabilities" {
  value = {
    management       = "definition"
    remote_lifecycle = false
    inference_api    = "responses"
  }
}

output "runtime" {
  description = "A template for the consuming application. Supply input and credentials at runtime; Terraform makes no inference request."
  value = {
    base_url    = "https://api.x.ai/v1"
    path        = "/responses"
    method      = "POST"
    api_key_env = "XAI_API_KEY"
    request_template_json = jsonencode(merge(jsondecode(var.options.settings_json), {
      model        = var.model
      instructions = var.instructions
      tools        = jsondecode(var.options.tools_json)
    }))
  }
}
