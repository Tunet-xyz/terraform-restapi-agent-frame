output "agent" {
  description = "Common agent handle. version is supplied for Claude and is null for OpenAI. No session is started."
  value       = var.vendor == "openai" ? module.openai[0].agent : module.anthropic[0].agent
}
