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
    base_url      = optional(string)
    api_key_env   = optional(string)
  })
  default  = {}
  nullable = false
}
