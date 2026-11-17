terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    claude = {
      source  = "modus-agendi/anthropic-claude-managed-agents"
      version = "~> 1.1.0"
    }
  }
}

resource "claude-managed-agents_agent" "this" {
  provider = claude

  name        = var.name
  model       = var.model
  system      = var.instructions == "" ? null : var.instructions
  metadata    = length(var.metadata) == 0 ? null : var.metadata
  description = var.options.description
  tools       = var.options.tools
  mcp_servers = var.options.mcp_servers
  skills      = var.options.skills
  multiagent  = var.options.multiagent
}

output "agent" {
  description = "Reusable agent handle with the current optimistic-locking version."
  value = {
    id       = claude-managed-agents_agent.this.id
    vendor   = "anthropic"
    name     = var.name
    model    = var.model
    version  = claude-managed-agents_agent.this.version
    archived = claude-managed-agents_agent.this.archived_at != null
  }
}
