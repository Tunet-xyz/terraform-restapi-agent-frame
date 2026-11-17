run "all_reviewed_profiles" {
  command = apply
  module { source = "./tests/fixtures/frontier" }
  assert {
    condition = length(output.agents) == 9 && alltrue([for profile, assistant in output.agents : (
      assistant.agent.id == null && !assistant.capabilities.remote_lifecycle &&
      length(keys(assistant.agent)) == 6 && assistant.agent.model == "fixture-${profile}" &&
      assistant.definition.metadata.team == "test" && length(assistant.fingerprint) == 64 &&
      length(assistant.runtime_fingerprint) == 64 &&
      jsondecode(assistant.runtime.request_template_json).temperature == 0.2 &&
      !contains(keys(jsondecode(assistant.runtime.request_template_json)), "metadata")
    )])
    error_message = "Every profile must apply without credentials, retain the common handle and native settings, and report definition-only management."
  }
  assert {
    condition = alltrue([for profile, url in {
      muse       = "https://api.meta.ai/v1"
      deepseek   = "https://api.deepseek.com"
      qwen       = "https://fixture-workspace.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1"
      kimi       = "https://api.moonshot.ai/v1"
      glm        = "https://api.z.ai/api/paas/v4"
      minimax    = "https://api.minimax.io/v1"
      cohere     = "https://api.cohere.ai/compatibility/v1"
      nvidia     = "https://integrate.api.nvidia.com/v1"
      openrouter = "https://openrouter.ai/api/v1"
    } : output.agents[profile].runtime.base_url == url])
    error_message = "Use the reviewed vendor surface and normalize trailing slashes."
  }
  assert {
    condition = (
      output.agents.muse.agent.vendor == "meta" &&
      output.agents.muse.runtime.path == "/responses" &&
      output.agents.muse.runtime.api_key_env == "MODEL_API_KEY" &&
      jsondecode(output.agents.muse.runtime.request_template_json).instructions == "Use the declared tools." &&
      jsondecode(output.agents.muse.runtime.request_template_json).tools[0].name == "lookup" &&
      !contains(keys(jsondecode(output.agents.muse.runtime.request_template_json)), "input")
    )
    error_message = "Muse must use Responses, native flat function tools and runtime-supplied input."
  }
  assert {
    condition = alltrue([for profile, assistant in output.agents : (
      assistant.runtime.path == "/chat/completions" &&
      jsondecode(assistant.runtime.request_template_json).messages[0].role == (profile == "cohere" ? "developer" : "system") &&
      jsondecode(assistant.runtime.request_template_json).messages[0].content == "Use the declared tools." &&
      jsondecode(assistant.runtime.request_template_json).tools[0].function.name == "lookup"
    ) if profile != "muse"])
    error_message = "Chat profiles must preserve native function schemas and use the documented instruction role."
  }
}

run "muse_entrypoint" {
  command = apply
  module { source = "./modules/muse" }
  variables {
    name  = "Muse assistant"
    model = "caller-selected-muse"
  }
  assert {
    condition     = output.agent.vendor == "meta" && output.agent.id == null && output.runtime.protocol == "responses" && !contains(keys(jsondecode(output.runtime.request_template_json)), "tools") && !contains(keys(jsondecode(output.runtime.request_template_json)), "instructions")
    error_message = "The Muse entry point must share the contract and omit empty optional payload fields."
  }
}

run "custom_self_hosted_muse" {
  command = apply
  module { source = "./modules/inference" }
  variables {
    profile = "custom"
    name    = "Local Glimmer"
    model   = "caller-served-glimmer"
    custom_profile = {
      vendor   = "meta"
      protocol = "chat_completions"
      base_url = "http://127.0.0.1:8000/v1"
    }
  }
  assert {
    condition     = output.agent.vendor == "meta" && output.runtime.api_key_env == null && output.runtime.path == "/chat/completions" && length(jsondecode(output.runtime.request_template_json).messages) == 0
    error_message = "Self-hosted models must accept a caller-reviewed compatible endpoint without requiring a fake credential."
  }
}

run "custom_responses_gateway" {
  command = apply
  module { source = "./modules/inference" }
  variables {
    profile      = "custom"
    name         = "Future model"
    model        = "caller-model"
    instructions = "Review code."
    custom_profile = {
      vendor      = "future_vendor"
      protocol    = "responses"
      base_url    = "https://models.example/v1"
      api_key_env = "FUTURE_API_KEY"
    }
    options = {
      base_url    = "https://gateway.example/ai/v1/"
      api_key_env = "GATEWAY_API_KEY"
    }
  }
  assert {
    condition     = output.runtime.base_url == "https://gateway.example/ai/v1" && output.runtime.api_key_env == "GATEWAY_API_KEY" && jsondecode(output.runtime.request_template_json).instructions == "Review code."
    error_message = "A custom Responses profile and an explicit gateway override must not need a module source change."
  }
}

run "reject_unknown_profile" {
  command = plan
  module { source = "./modules/inference" }
  variables {
    profile = "typo"
    name    = "Assistant"
    model   = "model"
  }
  expect_failures = [var.profile]
}

run "qwen_requires_workspace_endpoint" {
  command = plan
  module { source = "./modules/inference" }
  variables {
    profile = "qwen"
    name    = "Assistant"
    model   = "model"
  }
  expect_failures = [var.options]
}

run "reject_embedded_conversation" {
  command = plan
  module { source = "./modules/inference" }
  variables {
    profile = "muse"
    name    = "Assistant"
    model   = "model"
    options = { settings_json = "{\"previous_response_id\":\"resp_123\"}" }
  }
  expect_failures = [var.options]
}

run "reject_embedded_credential" {
  command = plan
  module { source = "./modules/inference" }
  variables {
    profile = "deepseek"
    name    = "Assistant"
    model   = "model"
    options = { settings_json = "{\"Authorization\":\"fixture-key\"}" }
  }
  expect_failures = [var.options]
}

run "reject_url_credentials" {
  command = plan
  module { source = "./modules/inference" }
  variables {
    profile = "kimi"
    name    = "Assistant"
    model   = "model"
    options = { base_url = "https://user:password@models.example/v1" }
  }
  expect_failures = [var.options]
}

run "custom_requires_configuration" {
  command = plan
  module { source = "./modules/inference" }
  variables {
    profile = "custom"
    name    = "Assistant"
    model   = "model"
  }
  expect_failures = [var.custom_profile]
}

run "reject_unsupported_custom_protocol" {
  command = plan
  module { source = "./modules/inference" }
  variables {
    profile = "custom"
    name    = "Assistant"
    model   = "model"
    custom_profile = {
      vendor   = "future_vendor"
      protocol = "imaginary_agent_crud"
      base_url = "https://models.example/v1"
    }
  }
  expect_failures = [var.custom_profile]
}
