terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 2.0.1"
    }
  }
}

variable "openai_api_key" {
  type      = string
  sensitive = true
  ephemeral = true
}

variable "model" {
  description = "An OpenAI model available to your project and the Agents API."
  type        = string
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

module "assistant" {
  source    = "../../modules/openai"
  providers = { restapi = restapi }

  name         = "Support assistant"
  model        = var.model
  instructions = "Prepare clear, concise support answers."
  metadata     = { team = "support" }
}

output "agent" {
  value = module.assistant.agent
}
