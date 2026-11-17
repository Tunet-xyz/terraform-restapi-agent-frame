terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 2.0.1"
    }
  }
}

variable "api_key" {
  type      = string
  sensitive = true
  ephemeral = true
}
variable "model" {
  type = string
}

provider "restapi" {
  uri                  = "https://api.mistral.ai/v1"
  write_returns_object = true
  timeout              = 60
  headers              = { Authorization = "Bearer ${var.api_key}" }
}

module "assistant" {
  source       = "../../modules/mistral"
  providers    = { restapi = restapi }
  name         = "Support assistant"
  model        = var.model
  instructions = "Prepare clear, concise support answers."
  metadata     = { team = "support" }
}

output "agent" {
  value = module.assistant.agent
}
