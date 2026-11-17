# AgentFrame Terraform modules

AgentFrame provides common agent inputs and handles across OpenAI, Claude,
Mistral, Gemini, Grok, Muse and other frontier model backends. Each backend
declares whether it provisions a remote resource or exports an application
definition. Model IDs and credentials belong to the caller.

This is the Terraform release export of
[Tunet-xyz/agent_frame](https://github.com/Tunet-xyz/agent_frame), version
`0.6.1`, from revision `16969a4a7d2ebaa03732da2de21b2b1b0be61b7c`. The canonical project contains the
MCP server, Python package, containers, design notes and issue tracker.
Implementation changes belong there. `SOURCE.json` records this export's source
and file hashes. The Terraform files are copied without resource-address changes.

## Installation

Once listed on the Terraform Registry, use `Tunet-xyz/agent-frame/restapi` for
the compatibility root and `//modules/NAME` for independent backends. For example,
Muse exports a definition and request template without deploying a cloud resource:

```hcl
module "assistant" {
  source  = "Tunet-xyz/agent-frame/restapi//modules/muse"
  version = "0.6.1"

  name         = "Review assistant"
  model        = "YOUR_ACCOUNT_ENABLED_MODEL"
  instructions = "Help the team review changes."
}
```

The public Git source also works independently of Registry account setup:

```hcl
module "assistant" {
  source = "git::https://github.com/Tunet-xyz/terraform-restapi-agent-frame.git//modules/muse?ref=v0.6.1"

  name  = "Review assistant"
  model = "YOUR_ACCOUNT_ENABLED_MODEL"
}
```

Use `modules/openai`, `modules/anthropic`, `modules/mistral` or `modules/gemini`
for remote-resource entry points. Use `modules/grok`, `modules/muse` or
`modules/inference` for portable definitions, `modules/rest` for a caller-reviewed
REST API profile, and `modules/catalog` for capability discovery. The root
selector supports OpenAI and Claude and requires both of its declared providers;
single-vendor deployments should use the corresponding submodule.

See [the upstream usage guide](https://github.com/Tunet-xyz/agent_frame/blob/v0.6.1/README.md)
for provider configuration, credentials, options, lifecycle/import behavior and
the shared six-field handle. Read the
[publication status](https://github.com/Tunet-xyz/agent_frame/blob/main/docs/registry-publishing.md)
for initial Registry indexing. AgentFrame is a module reusing existing
providers; this repository does not contain a custom Terraform provider plugin.

## Verification and license

Run `terraform fmt -check -recursive`, `terraform init -backend=false`,
`terraform validate`, `terraform test`, and the three Python CLI suites in
`tests/`. They use fake keys and local contract fixtures. No MCP package or
GitHub Actions workflow is included in this export. There is no graphical UI.

AgentFrame is available under the [MIT license](LICENSE), copyright Tunet Ltd.
