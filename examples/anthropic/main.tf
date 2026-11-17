terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    claude = {
      source  = "modus-agendi/anthropic-claude-managed-agents"
      version = "~> 1.1.0"
    }
  }
}

variable "model" {
  description = "A Claude model available to your workspace and Managed Agents."
  type        = string
}

provider "claude" {}

module "assistant" {
  source    = "../../modules/anthropic"
  providers = { claude = claude }

  name         = "Support assistant"
  model        = var.model
  instructions = "Prepare clear, concise support answers."
  metadata     = { team = "support" }
  options = {
    tools = [{
      type = "agent_toolset_20260401"
      default_config = {
        enabled           = false
        permission_policy = { type = "always_ask" }
      }
    }]
  }
}

output "agent" {
  value = module.assistant.agent
}
