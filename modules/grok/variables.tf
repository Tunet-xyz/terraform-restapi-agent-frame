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
  type     = map(string)
  default  = {}
  nullable = false
}
variable "options" {
  type = object({
    tools_json    = optional(string, "[]")
    settings_json = optional(string, "{}")
  })
  default  = {}
  nullable = false
  validation {
    condition = try(length(setintersection(
      toset(keys(jsondecode(var.options.settings_json))),
      toset(["model", "instructions", "tools", "input", "api_key", "authorization", "previous_response_id"])
    )) == 0, false)
    error_message = "settings_json must be an object and cannot override common fields, supply credentials/input, or bind a previous response. Supply input and any continuation at runtime."
  }
}
