# Gemini through the official Google provider

`modules/gemini` uses `hashicorp/google` 8.11.x and the native
`google_vertex_ai_reasoning_engine` resource. It deploys an ADK `LlmAgent`
configuration through `spec.source_code_spec.agent_config_source.adk_config`.
The common model and instructions become the deployed agent's `model` and
`instruction`; they are not merely labels on an empty cloud resource.

Google's [Terraform deployment guide](https://docs.cloud.google.com/gemini-enterprise-agent-platform/scale/runtime/use-terraform)
confirms native Terraform coverage. The
[8.11.0 resource reference](https://github.com/hashicorp/terraform-provider-google/blob/v8.11.0/website/docs/r/vertex_ai_reasoning_engine.html.markdown)
documents the config source, identity, method declarations, and deployment
settings used here. Google Cloud runtime coverage is distinct from the
standalone Gemini Developer API and its managed-agent products.

## Inputs and prerequisites

Use [examples/gemini](../examples/gemini/main.tf) with an existing GCP project,
supported regional runtime location, and runtime service-account email. Configure
non-interactive ADC or workload identity for the Google provider.

The platform must already have the Agent Platform/Vertex AI API, Cloud Build,
and Artifact Registry enabled, with the service-agent, build, artifact, and
model-access permissions required by Google's deployment guide. This module
owns the agent runtime resource; the calling platform configuration owns its
project setup and identities. No live cloud deployment has been performed here.

| Common input | Native behavior |
| --- | --- |
| `name` | Human-readable runtime display name |
| `model` | Model identifier in ADK config |
| `instructions` | ADK `instruction` string |
| `metadata` | Managed GCP labels, with lowercase/length validation; other labels remain outside Terraform ownership |
| `options.agent_name` | ADK Python identifier, default `agent`, separate from the display name |
| `options.tools_json` | ADK config tool array, default `[]` |

`options.project`, `region`, and `service_account` are required.
`options.model_location` defaults to `global` and configures the model endpoint;
the runtime's `region` is a separate setting. The runtime environment selects
Vertex AI authentication and the supplied project, so no Gemini API key is
embedded in its definition.

Use [ADK config syntax](https://adk.dev/agents/config/) for built-in tools.
Custom Python tool packages use other package/container deployment modes in the
native provider; this entry point deploys configuration rather than uploading a
custom source archive.

## Runtime methods and scaling

The checked-in [ADK method schemas](../modules/gemini/adk-methods.json) contain the
11 standard methods from the provider's 8.11.0 reference, including session
operations and streaming queries. They were extracted as literal data, with
prose descriptions omitted. Advertising methods is necessary for SDK discovery.
Supply `options.class_methods_json` when your runtime requires different method
declarations; review them when upgrading ADK or the provider.

Instance limits default to min 1, max 1. The adapter accepts min 1-10 and max
1-1000, with max at least min. The pinned provider omitted a zero minimum from
its create payload in the local contract test, causing the documented server
default of 1 to produce a perpetual diff. The adapter rejects zero until that
provider behavior is fixed and verified.

`options.deletion_policy` accepts `DELETE` (default) or `PREVENT`. The common
handle returns the resource's full ID and a null version; native revisions,
traffic promotion, runtime sessions, and inference stay with their platform APIs.

## Imports and verification

```shell
terraform import 'module.assistant.google_vertex_ai_reasoning_engine.this' 'projects/PROJECT/locations/REGION/reasoningEngines/ID'
```

The real provider is exercised through Terraform against a local HTTP API
fixture, including long-running operation responses, create/update/read/delete,
imports, drift, permission errors, identity handling, non-authoritative labels,
and credential exclusion from state and saved plans. This verifies provider
requests and Terraform behavior. Live project IAM, model access, build execution,
runtime health, and inference remain unverified in a real GCP account.
