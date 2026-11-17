variable "model" {
  description = "A Grok model available to your runtime account."
  type        = string
}

module "assistant" {
  source       = "../../modules/grok"
  name         = "Research assistant"
  model        = var.model
  instructions = "Research the user's question and cite reliable sources."
}

output "definition" {
  value = module.assistant.definition
}
output "runtime" {
  value = module.assistant.runtime
}
