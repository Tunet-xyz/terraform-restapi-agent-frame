# Muse and other model APIs

Reviewed on 16 November 2026. `modules/muse` provides a dedicated Meta Muse
entry point; `modules/inference` provides the same interface for nine reviewed
profiles and caller-defined compatible endpoints. These modules export an agent
definition and a request template. They create no remote agent, execute no
prompts, and require no Terraform provider or vendor credential. Their common
handle has `id = null` and `capabilities.remote_lifecycle = false`.

This extends the existing OpenAI, Claude, Mistral, Grok and Gemini adapters.
The [capability catalogue](../backends.json) distinguishes remote resources from
definitions and external cloud-provider coverage. It does not rank models or
promise that every model supports the same tools and settings.

## Reviewed profiles

| `profile` | Families / service | Base URL | Protocol | Runtime key environment name |
| --- | --- | --- | --- | --- |
| `muse` | Meta Muse Wonder, Spark, Ember | `https://api.meta.ai/v1` | Responses | `MODEL_API_KEY` |
| `deepseek` | DeepSeek | `https://api.deepseek.com` | Chat Completions | `DEEPSEEK_API_KEY` |
| `qwen` | Alibaba Qwen / Model Studio | Caller-supplied workspace and region URL | Chat Completions | `DASHSCOPE_API_KEY` |
| `kimi` | Moonshot Kimi | `https://api.moonshot.ai/v1` | Chat Completions | `MOONSHOT_API_KEY` |
| `glm` | Z.ai GLM | `https://api.z.ai/api/paas/v4` | Chat Completions | `ZAI_API_KEY` |
| `minimax` | MiniMax | `https://api.minimax.io/v1` | Chat Completions | `MINIMAX_API_KEY` |
| `cohere` | Cohere Command | `https://api.cohere.ai/compatibility/v1` | Chat Completions | `COHERE_API_KEY` |
| `nvidia` | Nemotron and other NVIDIA API Catalog models | `https://integrate.api.nvidia.com/v1` | Chat Completions | `NVIDIA_API_KEY` |
| `openrouter` | Caller-selected gateway models | `https://openrouter.ai/api/v1` | Chat Completions | `OPENROUTER_API_KEY` |

The [profile data](../modules/inference/profiles.json) includes official source
links and access notes. `ZAI_API_KEY` and `MINIMAX_API_KEY` are adapter conventions;
an SDK will need their values passed explicitly. Every environment name can be
overridden using `options.api_key_env`. These are names, never credential values.
The application chooses the vendor account, model entitlement and billing plan.

Sources: [Meta Model API](https://dev.meta.ai/docs/overview),
[Meta Responses](https://dev.meta.ai/docs/protocols/responses),
[DeepSeek quickstart](https://api-docs.deepseek.com/),
[Alibaba compatibility API](https://www.alibabacloud.com/help/en/model-studio/compatibility-of-openai-with-dashscope),
[Kimi quickstart](https://platform.kimi.ai/docs/get-your-api-key),
[Z.ai quickstart](https://docs.z.ai/guides/overview/quick-start),
[MiniMax compatibility API](https://platform.minimax.io/docs/api-reference/text-openai-api),
[Cohere compatibility API](https://docs.cohere.com/docs/compatibility-api),
[NVIDIA provider configuration](https://docs.nvidia.com/openshell/latest/sandboxes/manage-providers),
and [OpenRouter developer platform](https://openrouter.ai/developers).

OpenRouter also has an [official Terraform provider](https://github.com/OpenRouterTeam/terraform-provider-openrouter)
for keys, workspaces, guardrails and other platform administration. Use it for
those resources. Its reviewed resource catalogue does not provide saved-agent
definitions; this module supplies a portable inference definition separately.
No new remote-agent CRUD capability is claimed for the inference profiles.

## Terraform usage

All profiles accept `name`, `model`, `instructions`, `metadata` and `options`.
Select a model ID enabled for the intended endpoint; the module deliberately
does not select a changing latest alias.

```hcl
module "reviewer" {
  source = "git::https://github.com/Tunet-xyz/agent_frame.git//modules/inference?ref=v0.6.1"

  profile      = "deepseek" # muse, qwen, kimi, glm, minimax, cohere, nvidia, openrouter
  name         = "Code reviewer"
  model        = var.model
  instructions = "Explain concrete issues and suggest focused fixes."
  metadata     = { team = "platform" }
  options = {
    settings_json = jsonencode({ temperature = 0.2 })
  }
}
```

For Muse, `//modules/muse?ref=v0.6.1` fixes `profile = "muse"` internally.
[The Muse example](../examples/muse/main.tf) and
[multi-profile example](../examples/frontier/main.tf) use local module sources.
They need no provider block and no API keys during `init`, `plan` or `apply`.

| Option | Default | Meaning |
| --- | --- | --- |
| `tools_json` | `"[]"` | Native tool array for the selected API, preserved as JSON |
| `settings_json` | `"{}"` | Native model settings; supported fields depend on the model/API |
| `base_url` | Profile default | Override for a trusted gateway or regional endpoint; mandatory for Qwen |
| `api_key_env` | Profile default | Runtime environment variable name; Terraform never reads its value |

Core request fields, credentials, user input and continuation IDs cannot be
embedded in `settings_json`. `metadata` belongs to the portable definition and
is not sent to the inference API. Configuration appears in plans and state, so
keep secrets out of instructions, tools, settings, metadata and URLs.

Qwen's official guide now documents workspace-specific Model Studio hosts.
Set `options.base_url`, for example
`https://YOUR-WORKSPACE-ID.ap-southeast-1.maas.aliyuncs.com/compatible-mode/v1`
for the appropriate Singapore workspace. Obtain the actual URL and a matching
regional API key from your account. The module does not silently choose a region
or reuse an old shared DashScope hostname.

GLM uses the standard Z.ai endpoint; a Coding Plan has a separate endpoint.
Kimi Code and MiniMax subscriptions can similarly differ from ordinary API
access. For Cohere, tools and parameters must match its compatibility API.
NVIDIA and gateway models can have model-specific tool and instruction limits.
Native settings pass through; compatibility is verified locally for the template
contract, not against every vendor/model combination.

## Consume the runtime template

Outputs are `agent`, `definition`, `fingerprint`, `runtime_fingerprint`,
`capabilities` and `runtime`. `fingerprint` identifies definition content.
`runtime_fingerprint` also tracks endpoint, protocol, credential environment name
and request settings, so a gateway change can trigger an application deployment.
Neither fingerprint is a remote agent ID.

The application reads `runtime.request_template_json`, uses
`runtime.base_url + runtime.path` and the POST method, and supplies a bearer token
from the environment named by `runtime.api_key_env` when it is non-null.

- For `responses`, add `input` with the user's request. Muse uses top-level
  `instructions`. Meta documents that these instructions must be resent on turns
  using `previous_response_id`; the application owns that continuation policy.
- For `chat_completions`, append user messages to the template's `messages`
  array. Preserve its initial instruction message: `system` for most profiles,
  `developer` for Cohere. With empty instructions the initial array is empty.
- Preserve each API's native tool schema. Responses function tools are flat;
  Chat Completions function tools use a nested `function` object. Do not copy
  a tool array between protocols without adapting it.
- Preserve reasoning and tool-call history as required by the selected vendor.
  The application handles tool execution, streaming, retries and response parsing.

Empty optional instructions and tools are omitted where appropriate. Templates
are incomplete until the application adds user input. Terraform never reads
the key, sends the request, installs a model runtime or incurs inference charges.

## Custom endpoints and open models

An additional compatible model does not require another provider or a new
module. Use `profile = "custom"` with a caller-reviewed endpoint and protocol:

```hcl
module "local_muse" {
  source = "git::https://github.com/Tunet-xyz/agent_frame.git//modules/inference?ref=v0.6.1"

  profile      = "custom"
  name         = "Local Muse"
  model        = var.served_model_id
  instructions = "Help review code."
  custom_profile = {
    vendor   = "meta"
    protocol = "chat_completions" # or responses, if the server supports it
    base_url = "http://127.0.0.1:8000/v1"
    # api_key_env = "SELF_HOSTED_API_KEY" # omit for a server needing no token
  }
}
```

Custom Chat Completions profiles may set `instruction_role` to `system` (default)
or `developer`. URLs must use HTTPS or loopback HTTP and cannot contain userinfo,
query strings, fragments or unresolved placeholders. The consumer must trust
the selected host before sending credentials or data.

Meta's [Muse overview](https://dev.meta.ai/docs/overview) distinguishes hosted
Wonder/Spark/Ember from Muse Spark Open and Glimmer, whose weights run on your
own hardware or through a separate host. The custom example configures such an
existing compatible server; it does not deploy weights or GPU infrastructure.
Muse Image, speech and segmentation endpoints have separate payloads and are
outside this agent text/tool template. The same custom interface can describe
other compatible open models without hard-coding their names into Terraform.

To promote a custom endpoint to a reviewed profile, add its official source and
configuration to `modules/inference/profiles.json`, add a corresponding
definition entry to `backends.json`, and extend the endpoint/protocol tests.
`modules/catalog.inference_profiles` exposes the profile records to callers.

## Verification limits

The Terraform suite applies all nine profiles, Muse and custom endpoints without
credentials. Offline CLI checks forbid provider downloads, inspect saved plans
and state for fake credentials, exercise updates and cleared instructions, and
verify no-op plans and destroy. Existing real-provider fixtures cover the saved
agent and Google runtime adapters. No live inference, model-entitlement check or
vendor-account deployment was performed. No browser UI is part of this module.
