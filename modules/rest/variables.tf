variable "vendor" {
  type     = string
  nullable = false
  validation {
    condition     = can(regex("^[a-z][a-z0-9_-]*$", var.vendor))
    error_message = "vendor must be a lowercase identifier."
  }
}
variable "name" {
  type     = string
  nullable = false
  validation {
    condition     = length(trimspace(var.name)) > 0
    error_message = "name cannot be blank."
  }
}
variable "model" {
  type     = string
  nullable = false
  validation {
    condition     = length(trimspace(var.model)) > 0
    error_message = "model cannot be blank."
  }
}
variable "payload_json" {
  description = "Complete vendor-native agent payload, mapped by a backend adapter."
  type        = string
  nullable    = false
  validation {
    condition     = can(keys(jsondecode(var.payload_json)))
    error_message = "payload_json must be a JSON object."
  }
}
variable "endpoint" {
  description = "REST lifecycle profile. The caller configures the trusted origin and authentication on the restapi provider. Paths are relative to that origin."
  type = object({
    path              = string
    id_attribute      = optional(string, "id")
    create_method     = optional(string, "POST")
    read_path         = optional(string)
    update_method     = optional(string, "PATCH")
    update_path       = optional(string)
    destroy_method    = optional(string, "DELETE")
    destroy_path      = optional(string)
    ignore_changes_to = optional(list(string), ["id", "object", "created_at", "updated_at"])
  })
  nullable = false
  validation {
    condition = alltrue([
      for path in [var.endpoint.path, var.endpoint.read_path, var.endpoint.update_path, var.endpoint.destroy_path] :
      path == null ? true : can(regex("^/[^/?#][^?#]*$", path))
    ])
    error_message = "REST paths must be nonempty origin-relative paths without a query, fragment, or // prefix."
  }
  validation {
    condition = (contains(["POST", "PUT"], var.endpoint.create_method) &&
      contains(["POST", "PUT", "PATCH"], var.endpoint.update_method) &&
    contains(["DELETE", "POST"], var.endpoint.destroy_method))
    error_message = "Unsupported REST lifecycle HTTP method."
  }
}
