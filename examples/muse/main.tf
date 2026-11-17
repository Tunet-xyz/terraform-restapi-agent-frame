terraform {
  required_version = ">= 1.10.0, < 2.0.0"
}

variable "model" {
  description = "A Muse Wonder, Spark or Ember model ID enabled for your Meta Model API account."
  type        = string
}

module "assistant" {
  source = "../../modules/muse"

  name         = "Muse assistant"
  model        = var.model
  instructions = "Help the team plan and review changes."
  metadata     = { team = "platform" }
}

output "agent" {
  value = module.assistant.agent
}
output "runtime" {
  value = module.assistant.runtime
}
