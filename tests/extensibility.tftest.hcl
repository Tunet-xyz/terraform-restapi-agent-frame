mock_provider "restapi" {}

run "capability_catalog" {
  command = plan
  module { source = "./modules/catalog" }
  assert {
    condition     = !output.backends.grok.remote_lifecycle && output.backends.grok.module == "modules/grok" && output.backends.gemini.terraform_provider == "hashicorp/google" && output.backends.bedrock.module == null
    error_message = "The catalogue must distinguish portable definitions, implemented adapters, and external native-provider coverage."
  }
  assert {
    condition = length(output.inference_profiles) == 9 && alltrue([
      for profile in keys(output.inference_profiles) : (
        output.backends[profile].management == "definition" &&
        !output.backends[profile].remote_lifecycle &&
        output.backends[profile].terraform_provider == null &&
        output.backends[profile].inference_profile == profile
      )
    ]) && output.backends.muse.module == "modules/muse"
    error_message = "All reviewed inference profiles must be discoverable with an honest capability and the correct module/profile selector."
  }
}

run "new_vendor_definition" {
  command = plan
  module { source = "./modules/definition" }
  variables {
    vendor       = "new_vendor"
    name         = "Portable assistant"
    model        = "caller-selected-model"
    instructions = "Be helpful."
  }
  assert {
    condition     = output.definition.vendor == "new_vendor" && output.agent.id == null && length(output.fingerprint) == 64
    error_message = "New vendors must be supported without a fabricated remote ID."
  }
}

run "grok_request_template" {
  command = apply
  module { source = "./modules/grok" }
  variables {
    name         = "Grok assistant"
    model        = "caller-selected-grok"
    instructions = "Be helpful."
    options      = { settings_json = "{\"temperature\":0.2}" }
  }
  assert {
    condition     = !output.capabilities.remote_lifecycle && output.agent.id == null && jsondecode(output.runtime.request_template_json).instructions == "Be helpful." && !contains(keys(jsondecode(output.runtime.request_template_json)), "input")
    error_message = "Grok must produce a runtime template without executing inference or pretending to create a saved agent."
  }
}

run "grok_rejects_embedded_input" {
  command = plan
  module { source = "./modules/grok" }
  variables {
    name    = "Grok assistant"
    model   = "caller-selected-grok"
    options = { settings_json = "{\"input\":\"do this now\"}" }
  }
  expect_failures = [var.options]
}

run "custom_rest_profile" {
  command = plan
  module { source = "./modules/rest" }
  variables {
    vendor       = "custom"
    name         = "Custom assistant"
    model        = "custom-model"
    payload_json = "{\"name\":\"Custom assistant\"}"
    endpoint     = { path = "/assistants", update_method = "PUT" }
  }
  assert {
    condition     = restapi_object.this.path == "/assistants" && restapi_object.this.update_method == "PUT"
    error_message = "A backend must be able to select its documented endpoint and update method."
  }
}

run "rest_rejects_foreign_origin" {
  command = plan
  module { source = "./modules/rest" }
  variables {
    vendor       = "custom"
    name         = "Custom assistant"
    model        = "custom-model"
    payload_json = "{}"
    endpoint     = { path = "https://other.example/agents" }
  }
  expect_failures = [var.endpoint]
}

run "mistral_contract" {
  command = plan
  module { source = "./modules/mistral" }
  variables {
    name         = "Mistral assistant"
    model        = "caller-selected-mistral"
    instructions = "Be helpful."
  }
  assert {
    condition     = output.agent.vendor == "mistral" && output.capabilities.remote_lifecycle && output.definition.instructions == "Be helpful."
    error_message = "Mistral must use the portable definition and declare a real saved-agent lifecycle."
  }
}
