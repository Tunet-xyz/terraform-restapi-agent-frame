# Provider review — 16 November 2026

The question was whether vendor-maintained or community Terraform providers can
create and manage reusable OpenAI and Claude agents. The requested outcome is a
single module interface that reuses providers wherever practical.

## Findings

| Provider | Ownership | Registry downloads at review | Agent coverage |
| --- | --- | ---: | --- |
| `openai/openai` 1.5.0 | OpenAI-maintained | 150,122 | Administration, project controls, MCP tunnels and webhooks; no agent-definition resource in the reviewed catalogue |
| `mkdev-me/openai` 2.3.0 | Community | 1,821,676 | Broad inference/admin resources; no saved-agent resource in the reviewed registry catalogue |
| `jianyuan/openai` 0.7.1 | Community | 163,104 | Administration; no saved-agent resource in the reviewed catalogue |
| `ippontech/anthropic` 1.94.0 | Community | 101,507 | Agents and extensive organization/platform resources |
| `modus-agendi/anthropic-claude-managed-agents` | Community | 23,953 | Agents, environments, deployments, skills, vaults and memory stores |
| `frank-bee/anthropic` 0.7.3 | Community | 2,574 | Managed agents and platform/organization resources |
| `Mastercard/restapi` 3.0.0 | Community | 41,076,435 | Generic persistent REST-object lifecycle; suitable for the OpenAI agent endpoints |

Downloads are registry totals across versions, including CI activity. They are
evidence of distribution, not counts of production users. The available data
does not establish a universal community standard for agent management.

OpenAI calls its provider official in its own documentation. This is distinct
from HashiCorp's registry `official` tier, which describes HashiCorp-maintained
providers. The registry currently reports OpenAI's provider in the community
tier. I found no provider maintained by Anthropic in the vendor organization or
vendor registry namespaces checked.

## Implementation decision

Use one private repository and reuse existing providers. The generic REST
provider fills the current OpenAI saved-agent gap. Claude uses the agent-focused
Modus Agendi provider. Both sit behind the same core input/output contract.

The REST provider is constrained to 2.0.1. In the 3.0.0 contract checks,
`ignore_server_additions` hid edits to configured fields, and reading a remotely
deleted agent with targeted ignore fields failed during JSON parsing. The
selected 2.0.1 release passes those lifecycle checks. Explicit ignore fields
exclude API-owned timestamps and defaults while retaining managed-field drift.

The selection includes behavioral checks, not just download rankings. The
Ippon provider's reviewed update code sends a string map for metadata, which
cannot express the null values required to delete individual keys in the
documented metadata-patch API. Its response mapping also turns an empty system
string into Terraform null. These cases failed our local contract tests with
the initial wrapper. The selected provider implements metadata removal patches;
the module normalizes empty optional values to its schema.

Claude is constrained to the available signed 1.1.x release. Registry version
1.2.0 advertised GitHub checksum and binary URLs that returned 404 during this
review; the repository's latest published GitHub release was 1.1.0. Upgrade only
after installation and lifecycle checks pass.

The shared selector declares both providers. Single-vendor entry points expose
the same core interface without configuring an unrelated provider. Vendor tool
and orchestration options remain native to each platform.

## Primary sources

- [OpenAI Terraform guide](https://developers.openai.com/api/docs/guides/terraform)
  and [official provider resource catalogue](https://github.com/openai/terraform-provider-openai/tree/main/docs/resources).
- [OpenAI saved-agent configuration](https://developers.openai.com/api/docs/guides/agents-api/configuration)
  and [official SDK lifecycle implementation](https://github.com/openai/openai-python/blob/main/src/openai/resources/beta/agents/agents.py).
- [Claude Managed Agents](https://platform.claude.com/docs/en/managed-agents/overview)
  and [agent update API, including metadata patches](https://platform.claude.com/docs/en/api/beta/agents/update).
- [Ippon provider](https://registry.terraform.io/providers/ippontech/anthropic/latest)
  and [reviewed 1.94.0 agent implementation](https://github.com/ippontech/terraform-provider-anthropic/blob/v1.94.0/internal/services/agents/agent_resource.go).
- [Selected Claude provider](https://registry.terraform.io/providers/modus-agendi/anthropic-claude-managed-agents/1.1.0)
  and [1.1.0 metadata-patch client types](https://github.com/modus-agendi/terraform-provider-anthropic-claude-managed-agents/blob/v1.1.0/internal/client/types.go).
- [REST API provider](https://registry.terraform.io/providers/Mastercard/restapi/2.0.1)
  and [its lifecycle/import reference](https://github.com/Mastercard/terraform-provider-restapi/blob/v2.0.1/docs/resources/object.md).
- Registry metadata/download totals were read from its public
  `/v1/providers/NAMESPACE/NAME` endpoints on the date above.

This review and the repository's automated checks use public documentation and
local fixtures. They are not a live validation against either vendor account.
