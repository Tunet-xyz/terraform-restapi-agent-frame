mock_provider "google" {}

variables {
  name         = "Gemini assistant"
  model        = "caller-selected-gemini"
  instructions = "Be helpful."
  metadata     = { team = "support" }
  options = {
    project         = "fixture-project"
    region          = "us-central1"
    service_account = "runtime@fixture-project.iam.gserviceaccount.com"
  }
}

run "native_adk_config" {
  command = plan
  module { source = "./modules/gemini" }
  assert {
    condition     = jsondecode(google_vertex_ai_reasoning_engine.this.spec[0].source_code_spec[0].agent_config_source[0].adk_config[0].json_config).instruction == var.instructions && jsondecode(google_vertex_ai_reasoning_engine.this.spec[0].source_code_spec[0].agent_config_source[0].adk_config[0].json_config).model == var.model
    error_message = "Common model and instructions must configure the deployed ADK agent, not just resource metadata."
  }
  assert {
    condition     = google_vertex_ai_reasoning_engine.this.labels.team == "support" && google_vertex_ai_reasoning_engine.this.spec[0].service_account == var.options.service_account && length(jsondecode(google_vertex_ai_reasoning_engine.this.spec[0].class_methods)) == 11
    error_message = "The native resource must receive labels, runtime identity, and standard ADK method declarations."
  }
  assert {
    condition     = output.agent.vendor == "google" && output.capabilities.native_provider == "hashicorp/google" && google_vertex_ai_reasoning_engine.this.spec[0].deployment_spec[0].max_instances == 1
    error_message = "The common handle and native scaling settings must be preserved."
  }
}

run "reject_invalid_gcp_labels" {
  command = plan
  module { source = "./modules/gemini" }
  variables { metadata = { "Team Name" = "Mixed Case" } }
  expect_failures = [var.metadata]
}

run "reject_invalid_runtime_identity" {
  command = plan
  module { source = "./modules/gemini" }
  variables {
    options = {
      project         = "fixture-project"
      region          = "us-central1"
      service_account = "not-a-service-account"
    }
  }
  expect_failures = [var.options]
}

run "reject_unsupported_scale_to_zero" {
  command = plan
  module { source = "./modules/gemini" }
  variables {
    options = {
      project         = "fixture-project"
      region          = "us-central1"
      service_account = "runtime@fixture-project.iam.gserviceaccount.com"
      min_instances   = 0
    }
  }
  expect_failures = [var.options]
}
