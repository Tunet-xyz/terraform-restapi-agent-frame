terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.11.0"
    }
  }
}

module "definition" {
  source = "../definition"

  vendor       = "google"
  name         = var.name
  model        = var.model
  instructions = var.instructions
  metadata     = var.metadata
  tools_json   = var.options.tools_json
}

locals {
  class_methods = var.options.class_methods_json == null ? file("${path.module}/adk-methods.json") : var.options.class_methods_json
}

resource "google_vertex_ai_reasoning_engine" "this" {
  project         = var.options.project
  region          = var.options.region
  display_name    = var.name
  description     = var.options.description
  labels          = var.metadata
  deletion_policy = var.options.deletion_policy

  spec {
    agent_framework = "google-adk"
    service_account = var.options.service_account
    class_methods   = jsonencode(jsondecode(local.class_methods))

    source_code_spec {
      agent_config_source {
        adk_config {
          json_config = jsonencode({
            agent_class = "LlmAgent"
            name        = var.options.agent_name
            description = coalesce(var.options.description, "Terraform-managed agent")
            model       = module.definition.definition.model
            instruction = module.definition.definition.instructions
            tools       = module.definition.definition.tools
          })
        }
      }
    }

    deployment_spec {
      min_instances = var.options.min_instances
      max_instances = var.options.max_instances
      env {
        name  = "GOOGLE_GENAI_USE_VERTEXAI"
        value = "true"
      }
      env {
        name  = "GOOGLE_CLOUD_PROJECT"
        value = var.options.project
      }
      env {
        name  = "GOOGLE_CLOUD_LOCATION"
        value = var.options.model_location
      }
    }
  }
}

output "agent" {
  value = {
    id       = google_vertex_ai_reasoning_engine.this.id
    vendor   = "google"
    name     = var.name
    model    = var.model
    version  = null
    archived = false
  }
}
output "definition" {
  value = module.definition.definition
}
output "capabilities" {
  value = {
    management       = "cloud_runtime"
    remote_lifecycle = true
    native_provider  = "hashicorp/google"
  }
}
