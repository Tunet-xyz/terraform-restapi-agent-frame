variable "vendor" {
  description = "Model vendor identifier; new vendors do not require changes to this module."
  type        = string
  nullable    = false
  validation {
    condition     = can(regex("^[a-z][a-z0-9_-]*$", var.vendor))
    error_message = "vendor must be a lowercase identifier."
  }
}

variable "name" {
  type     = string
  nullable = false
  validation {
    condition     = length(trimspace(var.name)) > 0 && length(var.name) <= 256
    error_message = "name must contain 1-256 characters and cannot be blank."
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

variable "instructions" {
  type     = string
  default  = ""
  nullable = false
}

variable "metadata" {
  type     = map(string)
  default  = {}
  nullable = false
  validation {
    condition     = alltrue([for value in values(var.metadata) : value != null])
    error_message = "metadata values must be non-null strings."
  }
}

variable "tools_json" {
  type     = string
  default  = "[]"
  nullable = false
  validation {
    condition     = can(jsondecode(var.tools_json)) && can(regex("^\\s*\\[", var.tools_json))
    error_message = "tools_json must be a valid JSON array in the vendor's native format."
  }
}

variable "settings_json" {
  type     = string
  default  = "{}"
  nullable = false
  validation {
    condition     = can(keys(jsondecode(var.settings_json)))
    error_message = "settings_json must be a valid JSON object."
  }
}
