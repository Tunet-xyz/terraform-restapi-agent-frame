variable "profile" {
  description = "Reviewed inference profile or custom. This does not select a Terraform resource provider."
  type        = string
  nullable    = false
  validation {
    condition     = contains(concat(keys(jsondecode(file("${path.module}/profiles.json")).profiles), ["custom"]), var.profile)
    error_message = "Select a reviewed inference profile from profiles.json, or custom with custom_profile."
  }
}
variable "name" {
  type     = string
  nullable = false
}
variable "model" {
  description = "Caller-selected model ID. No latest alias or model availability is assumed."
  type        = string
  nullable    = false
}
variable "instructions" {
  type     = string
  default  = ""
  nullable = false
}
variable "metadata" {
  description = "Portable definition metadata; not sent as inference API parameters."
  type        = map(string)
  default     = {}
  nullable    = false
}
variable "options" {
  type = object({
    tools_json    = optional(string, "[]")
    settings_json = optional(string, "{}")
    base_url      = optional(string)
    api_key_env   = optional(string)
  })
  default  = {}
  nullable = false
  validation {
    condition = try(length(setintersection(
      toset([for key in keys(jsondecode(var.options.settings_json)) : lower(key)]),
      toset(["model", "instructions", "messages", "input", "tools", "metadata", "api_key", "authorization", "headers", "base_url", "previous_response_id", "conversation", "thread_id"])
    )) == 0, false)
    error_message = "settings_json must be an object without common fields, credentials, user input or conversation state. Supply those at runtime."
  }
  validation {
    condition     = var.profile != "qwen" || var.options.base_url != null
    error_message = "Qwen requires options.base_url with your workspace- and region-specific Model Studio endpoint."
  }
  validation {
    condition     = var.options.base_url == null || can(regex("^(https://[A-Za-z0-9.-]+(:[0-9]+)?|http://(localhost|127\\.0\\.0\\.1|\\[::1\\])(:[0-9]+)?)(/[A-Za-z0-9._~/-]*)?$", var.options.base_url))
    error_message = "base_url must be HTTPS (or HTTP on loopback) without credentials, query, fragment or placeholders."
  }
  validation {
    condition     = var.options.api_key_env == null || can(regex("^[A-Za-z_][A-Za-z0-9_]*$", var.options.api_key_env))
    error_message = "api_key_env must name an environment variable, never contain an API key."
  }
}
variable "custom_profile" {
  description = "A caller-reviewed compatible inference endpoint. A null api_key_env means the application need not send a bearer token."
  type = object({
    vendor           = string
    protocol         = string
    base_url         = string
    api_key_env      = optional(string)
    instruction_role = optional(string, "system")
  })
  default = null
  validation {
    condition     = (var.profile == "custom") == (var.custom_profile != null)
    error_message = "Set custom_profile exactly when profile is custom."
  }
  validation {
    condition = var.custom_profile == null || try(
      can(regex("^[a-z][a-z0-9_-]*$", var.custom_profile.vendor)) &&
      contains(["responses", "chat_completions"], var.custom_profile.protocol) &&
      contains(["system", "developer"], var.custom_profile.instruction_role) &&
      can(regex("^(https://[A-Za-z0-9.-]+(:[0-9]+)?|http://(localhost|127\\.0\\.0\\.1|\\[::1\\])(:[0-9]+)?)(/[A-Za-z0-9._~/-]*)?$", var.custom_profile.base_url)) &&
      (var.custom_profile.api_key_env == null || can(regex("^[A-Za-z_][A-Za-z0-9_]*$", var.custom_profile.api_key_env))),
    false)
    error_message = "custom_profile needs a vendor identifier, supported protocol/role, HTTPS or loopback URL without credentials/query/fragment/placeholders, and an optional credential environment name."
  }
}
