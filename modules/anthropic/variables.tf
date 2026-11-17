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
  validation {
    condition     = length(var.instructions) <= 100000
    error_message = "instructions must be at most 100,000 characters."
  }
}

variable "metadata" {
  type     = map(string)
  default  = {}
  nullable = false
  validation {
    condition = length(var.metadata) <= 16 && alltrue([
      for key, value in var.metadata :
      length(key) > 0 && length(key) <= 64 && try(length(value) <= 512, false)
    ])
    error_message = "metadata supports up to 16 entries with keys up to 64 characters and non-null values up to 512 characters."
  }
}

variable "options" {
  type = object({
    description = optional(string)
    tools       = optional(any)
    mcp_servers = optional(any)
    skills      = optional(any)
    multiagent  = optional(any)
  })
  default  = {}
  nullable = false
}
