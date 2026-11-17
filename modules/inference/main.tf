terraform {
  required_version = ">= 1.10.0, < 2.0.0"
}

locals {
  profiles = jsondecode(file("${path.module}/profiles.json")).profiles
  fallback = {
    vendor           = "custom"
    protocol         = "chat_completions"
    base_url         = ""
    api_key_env      = null
    instruction_role = "system"
  }
  # Project only the common fields so custom profiles retain the same type.
  builtin = {
    vendor           = try(local.profiles[var.profile].vendor, local.fallback.vendor)
    protocol         = try(local.profiles[var.profile].protocol, local.fallback.protocol)
    base_url         = try(local.profiles[var.profile].base_url, local.fallback.base_url)
    api_key_env      = try(local.profiles[var.profile].api_key_env, null)
    instruction_role = try(local.profiles[var.profile].instruction_role, "system")
  }
  selected = var.profile == "custom" ? coalesce(var.custom_profile, local.fallback) : local.builtin
  base_url = trim(try(coalesce(var.options.base_url, local.selected.base_url), ""), "/")
  tools    = try(jsondecode(var.options.tools_json), [])
  settings = try(jsondecode(var.options.settings_json), {})
  # Omit empty tools; some compatible APIs reject an explicitly empty list.
  tool_fields = { for key, value in { tools = local.tools } : key => value if length(value) > 0 }

  request_template_json = local.selected.protocol == "responses" ? jsonencode(merge(
    local.settings,
    { for key, value in { model = var.model, instructions = var.instructions } : key => value if key == "model" || value != "" },
    local.tool_fields
    )) : jsonencode(merge(local.settings, {
      model = var.model
      messages = [for instruction in [var.instructions] : {
        role    = local.selected.instruction_role
        content = instruction
      } if instruction != ""]
  }, local.tool_fields))

  runtime = {
    protocol              = local.selected.protocol
    base_url              = local.base_url
    path                  = local.selected.protocol == "responses" ? "/responses" : "/chat/completions"
    method                = "POST"
    api_key_env           = try(coalesce(var.options.api_key_env, local.selected.api_key_env), null)
    request_template_json = local.request_template_json
  }
}

module "definition" {
  source = "../definition"

  vendor        = local.selected.vendor
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
output "runtime_fingerprint" {
  description = "Changes when the endpoint, credential environment name, protocol or request template changes."
  value       = sha256(jsonencode(local.runtime))
}
output "capabilities" {
  value = {
    management       = "definition"
    remote_lifecycle = false
    inference_api    = local.selected.protocol
  }
}
output "runtime" {
  description = "Application request template only. Supply user input, history, tool execution and credentials at runtime. Terraform makes no API calls."
  value       = local.runtime
}
