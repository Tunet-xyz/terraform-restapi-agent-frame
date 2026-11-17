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
    tools_json  = optional(string, "[]")
    description = optional(string)
  })
  default  = {}
  nullable = false
}
