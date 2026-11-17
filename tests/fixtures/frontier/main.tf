module "assistant" {
  for_each = jsondecode(file("${path.module}/../../../modules/inference/profiles.json")).profiles
  source   = "../../../modules/inference"

  profile      = each.key
  name         = "${each.key} fixture"
  model        = "fixture-${each.key}"
  instructions = "Use the declared tools."
  metadata     = { team = "test" }
  options = {
    base_url      = each.key == "qwen" ? "https://fixture-workspace.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1/" : null
    settings_json = jsonencode({ temperature = 0.2 })
    tools_json = each.key == "muse" ? jsonencode([
      { type = "function", name = "lookup", parameters = { type = "object", properties = {} } }
      ]) : jsonencode([
      { type = "function", function = { name = "lookup", parameters = { type = "object", properties = {} } } }
    ])
  }
}

output "agents" {
  value = { for profile, assistant in module.assistant : profile => {
    agent               = assistant.agent
    definition          = assistant.definition
    fingerprint         = assistant.fingerprint
    runtime_fingerprint = assistant.runtime_fingerprint
    capabilities        = assistant.capabilities
    runtime             = assistant.runtime
  } }
}
