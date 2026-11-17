mock_provider "restapi" {}
mock_provider "claude" {}

variables {
  vendor       = "openai"
  name         = "Test agent"
  model        = "test-model"
  instructions = "Be helpful."
  metadata     = { team = "test" }
}

run "openai_contract" {
  command = plan

  module { source = "./modules/openai" }

  variables {
    options = {
      tools_json       = "[{\"type\":\"web_search\"},{\"type\":\"function\",\"name\":\"lookup\",\"parameters\":{\"type\":\"object\"}}]"
      reasoning_effort = "high"
    }
  }

  assert {
    condition     = output.agent.vendor == "openai"
    error_message = "The common handle must identify OpenAI."
  }

  assert {
    condition     = jsondecode(restapi_object.this.data).instructions == var.instructions && jsondecode(restapi_object.this.data).metadata.team == "test"
    error_message = "Common instructions and metadata must reach OpenAI."
  }

  assert {
    condition     = restapi_object.this.update_method == "POST" && restapi_object.this.destroy_method == "DELETE" && jsondecode(restapi_object.this.data).tools[1].parameters.type == "object"
    error_message = "OpenAI lifecycle methods and heterogeneous tool schemas must be preserved."
  }
}

run "claude_contract" {
  command = plan

  module { source = "./modules/anthropic" }

  variables {
    options = {
      description = "Support helper"
      tools = [{
        type = "agent_toolset_20260401"
        default_config = {
          enabled           = false
          permission_policy = { type = "always_ask" }
        }
      }]
    }
  }

  assert {
    condition     = output.agent.vendor == "anthropic"
    error_message = "The common handle must identify Claude."
  }

  assert {
    condition     = claude-managed-agents_agent.this.system == var.instructions && claude-managed-agents_agent.this.metadata.team == "test" && !claude-managed-agents_agent.this.tools[0].default_config.enabled
    error_message = "Common fields and Claude-specific tool policies must reach Claude."
  }
}

run "select_openai" {
  command = plan
  assert {
    condition     = length(module.openai) == 1 && length(module.anthropic) == 0 && output.agent.vendor == "openai"
    error_message = "Only the selected vendor's module should exist."
  }
}

run "select_claude" {
  command = plan
  variables { vendor = "anthropic" }
  assert {
    condition     = length(module.anthropic) == 1 && length(module.openai) == 0 && output.agent.vendor == "anthropic"
    error_message = "Only the selected vendor's module should exist."
  }
}

run "reject_unknown_vendor" {
  command = plan
  variables { vendor = "unknown" }
  expect_failures = [var.vendor]
}

run "reject_blank_name" {
  command = plan
  variables { name = "   " }
  expect_failures = [var.name]
}

run "reject_nonarray_tools" {
  command = plan
  variables { openai = { tools_json = "{}" } }
  expect_failures = [var.openai]
}

run "reject_null_metadata_value" {
  command = plan
  variables { metadata = { team = null } }
  expect_failures = [var.metadata]
}
