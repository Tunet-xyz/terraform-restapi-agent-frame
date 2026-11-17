terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    google = {
      source  = "hashicorp/google"
      version = "~> 8.11.0"
    }
  }
}

variable "project" { type = string }
variable "region" { type = string }
variable "model" { type = string }
variable "service_account" { type = string }

# Uses the runner's existing ADC or workload identity, without interactive login.
provider "google" {
  project = var.project
  region  = var.region
}

module "assistant" {
  source       = "../../modules/gemini"
  providers    = { google = google }
  name         = "Support assistant"
  model        = var.model
  instructions = "Prepare clear, concise support answers."
  metadata     = { team = "support" }
  options = {
    project         = var.project
    region          = var.region
    service_account = var.service_account
  }
}

output "agent" {
  value = module.assistant.agent
}
