# Backend extension contract

Each adapter accepts `name`, `model`, `instructions`, `metadata`, and an optional
vendor-specific `options` object. It returns the six-field `agent` handle used by
the original modules: `id`, `vendor`, `name`, `model`, `version`, `archived`.
New fields such as `definition`, `fingerprint`, `runtime`, and `capabilities` are
separate outputs so existing handle consumers keep the same shape.

Use these building blocks:

- `modules/definition` validates and exports a schema-versioned definition for
  any vendor identifier. Its remote `agent.id` is null. A content fingerprint
  is an artifact/deployment trigger, never a remote ID.
- `modules/inference` adds reviewed Responses or Chat Completions runtime
  templates to that definition. Select a named profile or a caller-reviewed
  `custom_profile`. Adding a compatible vendor generally needs only a profile
  record and tests. [Muse and frontier setup](frontier.md) describes the contract.
- `modules/rest` manages a persistent JSON resource through the existing locked
  REST provider. A profile supplies its real path, HTTP methods, ID field,
  and response fields outside the managed payload. Its common version is null;
  version-aware publication needs a native adapter with reliable update outputs.
- A native cloud-provider adapter owns platform resources through that provider.
  It should require only its own provider configuration and credentials.
- `modules/catalog` exposes the reviewed [backend catalogue](../backends.json).
  A null module path means coverage exists in an external provider but this
  repository does not ship an adapter for it.

The catalogue also exports `inference_profiles`, including endpoint, protocol,
credential environment name, source and review notes. A definition profile has
no Terraform provider dependency. An official provider for the platform's
administration can be used separately where appropriate.

Terraform provider dependencies are static. Add independent vendor entry points
instead of adding every provider to the root selector and making users configure
unrelated credentials. The root selector and existing resource addresses remain
compatible with v0.1.0. New adapters can be composed next to it.

## Add a backend

1. Verify its current official control-plane API. Inference, an SDK agent loop,
   or an OpenAI-compatible chat endpoint does not establish saved-agent CRUD.
2. Choose a definition-only adapter, the REST profile, or the native provider.
   For a REST profile, map common inputs to a complete vendor payload and list
   API-owned fields explicitly. Preserve detection of remote edits to managed
   values. Do not infer endpoint paths from a model's name.
3. Keep vendor options native. Do not imply that tool schemas, system prompts,
   hosted runtimes, or publication/versioning behavior are equivalent.
4. Add an example with its own provider declaration and runtime-injected keys.
   Credentials must stay outside definitions, request payloads, plans and state.
5. Test create, update, cleared values, no-op plans, remote drift, import, errors,
   and deletion with the real provider against local contract fixtures. A pure
   definition adapter must apply without a vendor credential or inference call.
6. Add the documented capability and source to `backends.json`. Distinguish
   native-provider availability from implemented adapters and live verification.

## Grok

The reviewed xAI public API documents Responses, tools, stored response history,
collections and team management. No saved-agent CRUD API was found in that
reference. Stored responses are conversation artifacts with a retention period;
they are not persistent agent definitions.

`modules/grok` therefore produces a definition plus a Responses request template.
The consuming application supplies `input`, continuation state, and
`XAI_API_KEY` at runtime. Terraform does not submit prompts or generate billable
responses. `agent.id` is null and `capabilities.remote_lifecycle` is false.
The template is for an initial request: when continuing through
`previous_response_id`, omit `instructions` as required by the xAI API.
See [the example](../examples/grok/main.tf),
[Responses reference](https://docs.x.ai/developers/rest-api-reference/inference/responses),
and [management reference](https://docs.x.ai/developers/rest-api-reference/management).

## Mistral

`modules/mistral` maps the same core inputs to Mistral's beta saved-agent API. It
uses `POST /v1/agents`, `GET /v1/agents/{id}`, `PATCH /v1/agents/{id}`, and
`DELETE /v1/agents/{id}`. Changes create agent versions; the common handle's
version is null. Conversation execution and version aliases are outside
this module's scope. The currently supported native options are `tools_json`
and `description`; completion arguments, guardrails and handoffs remain outside
its managed payload. See [the example](../examples/mistral/main.tf) and
[Mistral's API reference](https://docs.mistral.ai/api/endpoint/beta/agents).

The resource address for import is
`module.assistant.module.backend.restapi_object.this`; its import ID is
`/agents/AGENT_ID`, with the REST provider URI set to `https://api.mistral.ai/v1`.

## Native cloud coverage

Google documents Terraform deployment through the official provider's
`google_vertex_ai_reasoning_engine`. This verifies the Google Cloud runtime path
for Gemini-backed agents; it does not mean every Gemini Developer API feature is
managed by that resource. See [Google's deployment guide](https://docs.cloud.google.com/gemini-enterprise-agent-platform/scale/runtime/use-terraform).

The repository's [Gemini adapter](../modules/gemini/main.tf) deploys a native ADK
configuration with that resource, isolated from other vendors' credentials.
See [setup, input mapping, and verified provider constraints](gemini.md).

AWS's official provider has
[`aws_bedrockagent_agent`](https://registry.terraform.io/providers/hashicorp/aws/latest/docs/resources/bedrockagent_agent).
Microsoft documents hosted Foundry agents with
[`azapi_data_plane_resource` and `Microsoft.Foundry/agents@v1`](https://learn.microsoft.com/en-us/azure/foundry/agents/how-to/deploy-hosted-agent-terraform).
Those are separate hosting platforms with their own model availability, identity,
artifact and deployment requirements. Their catalogue entries describe external
provider coverage unless a module path is present.
