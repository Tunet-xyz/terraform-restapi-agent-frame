terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 2.0.1"
    }
    claude = {
      source  = "modus-agendi/anthropic-claude-managed-agents"
      version = "~> 1.1.0"
    }
  }
}

variable "openai_api_key" {
  description = "Project API key, supplied as TF_VAR_openai_api_key. This is not an Admin API key."
  type        = string
  sensitive   = true
  ephemeral   = true
}

provider "restapi" {
  uri                  = "https://api.openai.com/v1"
  write_returns_object = true
  timeout              = 60
  headers = {
    Authorization = "Bearer ${var.openai_api_key}"
    OpenAI-Beta   = "agents=v1"
  }
}

# The provider reads ANTHROPIC_API_KEY. Use a workspace-scoped API key.
provider "claude" {}

module "openai_agent" {
  source = "../.."
  providers = {
    restapi = restapi
    claude  = claude
  }

  vendor       = "openai"
  name         = "Support assistant"
  model        = "gpt-6-astra"
  instructions = "Help the support team prepare clear, concise answers."
  metadata     = { team = "support" }
}

module "claude_agent" {
  source = "../.."
  providers = {
    restapi = restapi
    claude  = claude
  }

  vendor       = "anthropic"
  name         = "Support assistant"
  model        = "claude-sonnet-4-6"
  instructions = "Help the support team prepare clear, concise answers."
  metadata     = { team = "support" }
  anthropic = {
    tools = [{
      type = "agent_toolset_20260401"
      default_config = {
        enabled           = false
        permission_policy = { type = "always_ask" }
      }
    }]
  }
}

output "agents" {
  value = {
    openai = module.openai_agent.agent
    claude = module.claude_agent.agent
  }
}
