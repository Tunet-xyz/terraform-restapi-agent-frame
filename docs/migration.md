# Migrating to AgentFrame

Version 0.6.0 adopts the AgentFrame name across the repository, Python package,
MCP server and container distribution. The existing repository was renamed;
its identity, visibility, tags and published release assets are preserved.

| Surface | Previous name | AgentFrame name |
| --- | --- | --- |
| GitHub repository | `Tunet-xyz/terraform-agents` | `Tunet-xyz/agent_frame` |
| Python distribution | `tunet-agents-mcp` | `AgentFrame` |
| Python import / module launcher | `tunet_agents_mcp` | `agent_frame` |
| MCP console command | `tunet-agents-mcp` | `agent-frame-mcp` |
| MCP server identity | `tunet-terraform-agents` | `agent-frame`, title `AgentFrame` |
| Canonical MCP resource scheme | `terraform-agents://` | `agent-frame://` |
| Container image | `tunet-agents-mcp:VERSION` | `agent-frame-mcp:VERSION` |
| Image archive prefix | `tunet-agents-mcp_VERSION_...` | `agent-frame-mcp_VERSION_...` |
| Optional GHCR image | `ghcr.io/tunet-xyz/terraform-agents-mcp` | `ghcr.io/tunet-xyz/agent-frame-mcp` |

## Git and Terraform

Update an existing clone's remote:

```sh
git remote set-url origin https://github.com/Tunet-xyz/agent_frame.git
```

GitHub redirects the previous repository's web and Git URLs. Do not reuse
`terraform-agents` for a different repository, because that would break those
redirects. See [GitHub's rename behavior](https://docs.github.com/en/repositories/creating-and-managing-repositories/renaming-a-repository).

New Terraform configurations should use the new repository and release:

```hcl
module "assistant" {
  source = "git::https://github.com/Tunet-xyz/agent_frame.git//modules/muse?ref=v0.6.0"
  name   = "Review assistant"
  model  = var.model
}
```

Existing resource addresses, provider sources, common inputs and the six-field
agent handle have not changed. No Terraform state move or resource replacement
is needed for this branding change. Review a normal plan when upgrading;
instructions and model changes still have their usual backend-specific effects.

## Python and MCP

From an existing checkout, update to the new release and run `uv sync --frozen`.
This replaces the old project distribution with `AgentFrame`. Wheel filenames
use the normalized `agentframe` prefix. The native launch command is:

```sh
uv run --frozen agent-frame-mcp
```

For environments installed with pip instead of uv, uninstall the previous
`tunet-agents-mcp` distribution before installing the AgentFrame wheel. Both
distributions otherwise own the legacy launcher and compatibility namespace.

Client configurations should use `python -m agent_frame` or `agent-frame-mcp`,
and resources `agent-frame://catalog` and `agent-frame://inference-profiles`.

This release retains the legacy console command, Python module/import namespace
and both `terraform-agents://` resource URIs as compatibility aliases. They
delegate to the same implementation and catalogue. New integrations should use
the AgentFrame names. The four MCP tool names and their input/output contracts
are unchanged.

## Containers and existing releases

The v0.6.0 installers download archives from `Tunet-xyz/agent_frame` and create
the `agent-frame-mcp:0.6.0` client alias. They also recognize the legacy archive
prefix when explicitly installing a version earlier than 0.6.0.

Published v0.5.0 images, wheel and installers are historical artifacts and are
not renamed or replaced. The original release URLs redirect with the repository.
Existing clients can keep using those images while their configuration is
updated. Use [the current container setup](distribution.md) for new deployments.

The optional GHCR workflow targets the new image name and remains manual-only.
No workflow was dispatched and no package or repository was made public as
part of this rename. Terraform Registry account onboarding and any separate
Registry publishing repository remain distinct, unfinished setup steps.

Version 0.6.1 subsequently makes AgentFrame public under MIT and prepares the
Registry source repository. See [the current publication status](registry-publishing.md).
