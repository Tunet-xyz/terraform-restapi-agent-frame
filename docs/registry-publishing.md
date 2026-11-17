# Terraform Registry publication

Reviewed on 17 November 2026. AgentFrame is a **Terraform module** reusing
existing providers, plus an MCP server. It has no Terraform provider plugin.
The appropriate listing for the current implementation is a module listing.

HashiCorp's [provider publishing guide](https://developer.hashicorp.com/terraform/registry/providers/publishing)
requires an actual provider, a public `terraform-provider-NAME` repository,
provider documentation, release binaries, checksums and signing material.
Registering a publisher account does not turn Terraform module code into a
provider. A custom provider would be a separate implementation and maintenance
commitment; it is not needed to reuse the providers selected here.

## Public module source

HashiCorp's [module publishing requirements](https://developer.hashicorp.com/terraform/registry/modules/publish)
require a public GitHub repository named `terraform-PROVIDER-NAME`, a description,
standard module structure and semantic version tags. Publishing connects the
publisher's GitHub account to the Registry and authorizes repository webhooks.

Current status:

| Requirement | Status |
| --- | --- |
| Reusable module with root and independent submodules | Present |
| README, examples, declared inputs/outputs and provider dependencies | Present |
| Version tags | Present |
| Canonical public project | `Tunet-xyz/agent_frame` |
| License | MIT, copyright Tunet Ltd; see [LICENSE](../LICENSE) |
| Registry source repository | `Tunet-xyz/terraform-restapi-agent-frame` |
| Version | `v0.6.1` |
| Intended Registry address | `Tunet-xyz/agent-frame/restapi` |
| Initial Registry publication | Pending the owner's GitHub OAuth connection and Publish Module action |

The canonical project keeps its `agent_frame` name, MCP package and container
distribution. The companion Registry repository contains the Terraform release
source, examples, contract fixtures, catalogue, documentation and license.
Its `restapi` segment identifies the compatibility root's primary provider;
the other vendor submodules remain available in the same package.

The Registry repository is a release export, not an independent implementation.
Its `SOURCE.json` records the immutable upstream revision and exported file
hashes. Terraform modules and resource addresses are preserved. Changes belong
in `agent_frame` first, then a reviewed and tested export receives the matching
semantic version tag. No Python package, Docker image, provider binary, local
state, credentials or GitHub Actions workflow is included in the export.

## Complete the initial listing

1. Open Upload on the [Terraform Registry](https://registry.terraform.io/).
2. Connect the owner's GitHub identity and grant Tunet-xyz access where needed.
3. Choose `Tunet-xyz/terraform-restapi-agent-frame` and Publish Module.
4. Verify `0.6.1` appears at `Tunet-xyz/agent-frame/restapi`, then test a fresh
   `terraform init` using that Registry address.

No Registry authentication is configured in the agent environment, and no
Terraform connector was found. The public Registry's documented API exposes
module discovery and downloads; initial publication uses the owner's GitHub
OAuth session. No user's browser profile or signed-in session is accessed.

The intended address is not advertised as a live listing until the Registry
versions API returns it and a fresh CLI initialization succeeds. Until then,
the public Git sources are usable directly without a Registry account.

Once connected, the Registry's webhook observes subsequent version tags.
GitHub Actions remains manual-only; agents do not start workflows.
