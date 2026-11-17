terraform {
  required_version = ">= 1.10.0, < 2.0.0"
  required_providers {
    restapi = {
      source  = "Mastercard/restapi"
      version = "~> 2.0.1"
    }
  }
}

resource "restapi_object" "this" {
  path              = var.endpoint.path
  id_attribute      = var.endpoint.id_attribute
  create_method     = var.endpoint.create_method
  read_method       = "GET"
  read_path         = var.endpoint.read_path
  update_method     = var.endpoint.update_method
  update_path       = var.endpoint.update_path
  destroy_method    = var.endpoint.destroy_method
  destroy_path      = var.endpoint.destroy_path
  ignore_changes_to = var.endpoint.ignore_changes_to
  data              = var.payload_json
}

output "agent" {
  description = "Normalized handle for a remotely persisted REST object."
  value = {
    id       = restapi_object.this.id
    vendor   = var.vendor
    name     = var.name
    model    = var.model
    version  = null
    archived = false
  }
}
