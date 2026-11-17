variable "vendor" {
  description = "Platform that owns the persistent agent: openai or anthropic. Changing it replaces the agent."
  type        = string
  nullable    = false

  validation {
    condition     = contains(["openai", "anthropic"], var.vendor)
    error_message = "The compatibility root selector accepts openai or anthropic. Use a per-vendor entry point from the backend catalogue for other platforms."
  }
}

variable "name" {
  description = "Human-readable agent name (1-256 characters)."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.name)) > 0 && length(var.name) <= 256
    error_message = "name must contain 1-256 characters and cannot be blank."
  }
}

variable "model" {
  description = "Vendor model identifier. Availability and access are checked by the vendor API."
  type        = string
  nullable    = false

  validation {
    condition     = length(trimspace(var.model)) > 0
    error_message = "model cannot be blank."
  }
}

variable "instructions" {
  description = "Agent instructions, mapped to OpenAI instructions or Claude system. OpenAI appends these to its base instructions."
  type        = string
  default     = ""
  nullable    = false

  validation {
    condition     = length(var.instructions) <= 100000
    error_message = "instructions must be at most 100,000 characters (the common platform limit)."
  }
}

variable "metadata" {
  description = "Up to 16 metadata entries; keys have at most 64 characters and values at most 512."
  type        = map(string)
  default     = {}
  nullable    = false

  validation {
    condition = length(var.metadata) <= 16 && alltrue([
      for key, value in var.metadata :
      length(key) > 0 && length(key) <= 64 && try(length(value) <= 512, false)
    ])
    error_message = "metadata supports up to 16 entries, nonempty keys up to 64 characters, and non-null values up to 512 characters."
  }
}

variable "openai" {
  description = "OpenAI settings. tools_json is a vendor-native JSON array so heterogeneous tool definitions retain their types. Omitted tools are cleared; omitted reasoning resets to the model default."
  type = object({
    tools_json       = optional(string, "[]")
    reasoning_effort = optional(string)
    service_tier     = optional(string, "auto")
  })
  default  = {}
  nullable = false

  validation {
    condition     = can(jsondecode(var.openai.tools_json)) && can(regex("^\\s*\\[", var.openai.tools_json))
    error_message = "openai.tools_json must be a valid JSON array."
  }

  validation {
    condition     = contains(["auto", "default", "flex", "priority", "fast", "ultrafast"], var.openai.service_tier)
    error_message = "openai.service_tier must be auto, default, flex, priority, fast, or ultrafast."
  }
}

variable "anthropic" {
  description = "Claude-specific settings passed to modus-agendi/anthropic-claude-managed-agents. Nested objects follow that provider's schema."
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
