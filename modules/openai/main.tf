terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 2.0.1"
    }
  }
}

resource "restapi_object" "this" {
  path           = "/agents"
  id_attribute   = "id"
  create_method  = "POST"
  read_method    = "GET"
  update_method  = "POST"
  destroy_method = "DELETE"
  # Exclude only fields this module does not manage. Keep normal drift reads:
  # restapi 3.0.0's ignore_server_additions also suppresses configured-field drift.
  ignore_changes_to = concat([
    "id", "object", "created_at", "updated_at", "text", "compaction",
    "experimental", "multi_agent", "async", "time_awareness",
  ], var.options.reasoning_effort == null ? ["reasoning"] : [])
  data = jsonencode({
    name         = var.name
    model        = var.model
    instructions = var.instructions
    metadata     = var.metadata
    tools        = jsondecode(var.options.tools_json)
    reasoning    = var.options.reasoning_effort == null ? null : { effort = var.options.reasoning_effort }
    service_tier = var.options.service_tier
  })
}

output "agent" {
  description = "Reusable agent handle; this does not start a session."
  value = {
    id       = restapi_object.this.id
    vendor   = "openai"
    name     = var.name
    model    = var.model
    version  = null
    archived = false
  }
}
