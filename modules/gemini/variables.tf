variable "name" {
  type     = string
  nullable = false
}
variable "model" {
  type     = string
  nullable = false
}
variable "instructions" {
  type     = string
  default  = ""
  nullable = false
}
variable "metadata" {
  description = "Managed GCP labels; other resource labels are non-authoritative and remain outside this module."
  type        = map(string)
  default     = {}
  nullable    = false
  validation {
    condition = length(var.metadata) <= 63 && alltrue([
      for key, value in var.metadata :
      can(regex("^[a-z][a-z0-9_-]{0,62}$", key)) && can(regex("^[a-z0-9_-]{0,63}$", value))
    ])
    error_message = "Gemini metadata becomes GCP labels: at most 63 lowercase entries, keys start with a letter, values may be empty, and each key/value has at most 63 characters using letters, digits, _ or -."
  }
}
variable "options" {
  type = object({
    project            = string
    region             = string
    service_account    = string
    model_location     = optional(string, "global")
    agent_name         = optional(string, "agent")
    description        = optional(string)
    tools_json         = optional(string, "[]")
    class_methods_json = optional(string)
    min_instances      = optional(number, 1)
    max_instances      = optional(number, 1)
    deletion_policy    = optional(string, "DELETE")
  })
  nullable = false
  validation {
    condition = (length(trimspace(var.options.project)) > 0 && length(trimspace(var.options.region)) > 0 &&
      can(regex("^[^@]+@[^@]+\\.iam\\.gserviceaccount\\.com$", var.options.service_account)) &&
    can(regex("^[A-Za-z_][A-Za-z0-9_]*$", var.options.agent_name)))
    error_message = "Supply project, region, a runtime service-account email, and a Python-compatible ADK agent_name."
  }
  validation {
    condition = (var.options.min_instances >= 1 && var.options.min_instances <= 10 &&
      floor(var.options.min_instances) == var.options.min_instances &&
      var.options.max_instances >= 1 && var.options.max_instances <= 1000 &&
    floor(var.options.max_instances) == var.options.max_instances && var.options.max_instances >= var.options.min_instances)
    error_message = "Use integer instance limits: min 1-10, max 1-1000, with max >= min. The pinned provider omits zero on create, so this adapter does not support min_instances = 0."
  }
  validation {
    condition     = contains(["DELETE", "PREVENT"], var.options.deletion_policy)
    error_message = "deletion_policy must be DELETE or PREVENT."
  }
  validation {
    condition = var.options.class_methods_json == null ? true : try(
      can(regex("^\\s*\\[", var.options.class_methods_json)) &&
      length(jsondecode(var.options.class_methods_json)) > 0 && alltrue([
        for method in jsondecode(var.options.class_methods_json) :
        can(regex("^[A-Za-z_][A-Za-z0-9_]*$", method.name)) && can(keys(method.parameters))
      ]), false
    )
    error_message = "class_methods_json must be a nonempty array of method objects with a name and an OpenAPI parameters object."
  }
}
