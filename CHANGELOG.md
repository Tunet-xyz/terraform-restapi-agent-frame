# Changelog

## v0.6.1

- Publish AgentFrame under the MIT license, matching Tunet's public projects.
  Include the license in Python distributions and container images.
- Remove private-source installation requirements. Container installers download
  public release assets directly over HTTPS without a GitHub login.
- Prepare a Terraform-only release source, `terraform-restapi-agent-frame`, for
  the Registry module address `Tunet-xyz/agent-frame/restapi`. Initial Registry
  publication requires the owner's GitHub OAuth connection.

## v0.6.0

- Rename the project to AgentFrame and the GitHub repository to `agent_frame`,
  preserving repository identity, visibility, existing tags and release assets.
- Rename the Python distribution to `AgentFrame`, import namespace to
  `agent_frame`, MCP command to `agent-frame-mcp`, and canonical resources to
  `agent-frame://`. Retain the previous Python, console and resource names as
  compatibility aliases.
- Update container images, archive names, installers, workflows and generated
  Terraform Git sources to the AgentFrame identity. Existing release binaries
  remain unchanged; installers recognize legacy archive names for old versions.
- Document migration without changing Terraform resource addresses, provider
  dependencies, agent handles or backend behavior. Workflows remain manual-only.

## v0.5.0

- Add digest-pinned Linux amd64/arm64 MCP images with Python, frozen dependencies,
  Terraform and whitelisted module assets, running as a non-root user.
- Exercise every inference backend over real stdio with networking disabled,
  a read-only root and bounded temporary storage.
- Add verified image archives, SHA-256 manifests and PowerShell/shell installers
  for private GitHub Release distribution without host Python or Terraform.
- Add a user-started, manual-only multi-platform GHCR publishing workflow.
- Document Terraform Registry module/provider requirements and the remaining
  public-source or HCP account choices. No repository is made public or renamed.

## v0.4.0

- Add a local stdio MCP server using the official Python SDK, with four tools
  for catalogue discovery, backend details, Terraform configuration generation
  and provider-free definition compilation, plus two catalogue resources.
- Compile definitions with the existing bundled Terraform modules in isolated
  temporary workspaces; do not duplicate backend compilation in Python.
- Generate provider configuration for implemented remote-agent/cloud adapters
  with credential setup instructions and no embedded keys or deployments.
- Add strict input models, literal Terraform string handling, structured MCP
  results, dependency locking, and a wheel with whitelisted source assets.
- Test actual stdio connections, legacy negotiation, concurrent requests, error
  recovery, missing Terraform, and generated configurations; keep CI manual-only.

## v0.3.0

- Add a Meta Muse entry point for Wonder, Spark and Ember definitions and
  Responses request templates.
- Add one provider-free inference module with reviewed DeepSeek, Qwen, Kimi,
  GLM, MiniMax, Cohere, NVIDIA and OpenRouter profiles alongside Muse.
- Support future compatible APIs, trusted gateways and existing self-hosted
  models through custom Responses or Chat Completions profiles.
- Require Qwen's workspace/region endpoint, preserve native tool formats and
  instruction roles, and keep runtime credentials and input outside Terraform.
- Expand the capability catalogue and examples. Preserve existing remote-agent
  resource addresses and distinguish definitions from remote provisioning.
- Add offline CLI coverage for saved plans, updates, endpoint fingerprints,
  cleared instructions, no-op plans and destroy; keep Actions manual-only.

## v0.2.0

- Add a provider-neutral, schema-versioned agent definition and capability
  catalogue. New backends use independent entry points and the same core handle.
- Add Grok definitions and an initial Responses request template. Runtime input
  and credentials are supplied by the application; its remote agent ID is null.
- Add a reusable REST lifecycle profile and a Mistral saved-agent adapter.
- Add native Gemini ADK configuration deployment with the official Google
  provider, runtime identity, method declarations, label validation, and bounded
  instance settings. The pinned adapter requires a minimum of one instance.
- Record official AWS Bedrock and Azure Foundry Terraform coverage in the
  catalogue, with those external resources distinguished from shipped adapters.
- Preserve the original root selector's OpenAI/Claude resource addresses.
- Add local real-provider lifecycle checks for Mistral and Google, extending
  the manual-only validation workflow.

## v0.1.0

- Add OpenAI and Claude modules with common inputs and handles, usage examples,
  provider research, and local lifecycle verification.
