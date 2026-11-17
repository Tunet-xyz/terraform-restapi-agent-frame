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
