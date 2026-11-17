terraform {
  required_version = ">= 1.10.0, < 2.0.0"
}

variable "agents" {
  description = "Agent name to profile/model mapping. Use model IDs enabled for each account; qwen also needs its workspace endpoint."
  type = map(object({
    profile       = string
    model         = string
    instructions  = optional(string, "Help the team review changes.")
    tools_json    = optional(string, "[]")
    settings_json = optional(string, "{}")
    base_url      = optional(string)
    api_key_env   = optional(string)
  }))
}

module "assistant" {
  for_each = var.agents
  source   = "../../modules/inference"

  profile      = each.value.profile
  name         = each.key
  model        = each.value.model
  instructions = each.value.instructions
  metadata     = { team = "platform" }
  options = {
    tools_json    = each.value.tools_json
    settings_json = each.value.settings_json
    base_url      = each.value.base_url
    api_key_env   = each.value.api_key_env
  }
}

output "agents" {
  value = { for name, assistant in module.assistant : name => {
    agent        = assistant.agent
    capabilities = assistant.capabilities
    runtime      = assistant.runtime
  } }
}
