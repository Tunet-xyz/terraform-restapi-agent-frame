module "openai" {
  count = var.vendor == "openai" ? 1 : 0

  source = "./modules/openai"
  providers = {
    restapi = restapi
  }

  name         = var.name
  model        = var.model
  instructions = var.instructions
  metadata     = var.metadata
  options      = var.openai
}

module "anthropic" {
  count = var.vendor == "anthropic" ? 1 : 0

  source = "./modules/anthropic"
  providers = {
    claude = claude
  }

  name         = var.name
  model        = var.model
  instructions = var.instructions
  metadata     = var.metadata
  options      = var.anthropic
}
