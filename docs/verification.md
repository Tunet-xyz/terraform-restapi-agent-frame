# AgentFrame verification

## v0.6.1 — 17 November 2026

Public-release preparation passed the 30 Terraform tests, 5 saved-agent lifecycle
tests, 1 Google lifecycle test, 2 frontier CLI tests and 10 real stdio MCP tests
from a non-editable wheel installation. Both Linux container suites passed,
including ARM64 under emulation. The wheel and runtime images contain the MIT
license; Terraform's upstream license remains separate. The package metadata
declares `MIT` and no longer marks the source private.

PowerShell 7, Windows PowerShell and Linux shell checks exercise valid image
archives with CRLF manifests and reject corrupted archives before loading.
Public HTTPS delivery is checked separately after the release is published.
The installers no longer require GitHub CLI authentication. Documentation links,
frozen dependency metadata, Python lint and manual-only workflows pass.

Basic tracked-history checks found no supported key formats, private-key blocks,
Terraform state, variable files or local credential files. Only tracked source
is published; ignored local environments, caches and build outputs are excluded.
Existing tags and published assets are preserved by the visibility change.

Initial Terraform Registry publication remains dependent on the owner's GitHub
OAuth connection. A prepared GitHub repository and tag do not establish a live
Registry listing: the Registry versions API and a fresh CLI installation must
both succeed before that step is reported complete. See [publication status](registry-publishing.md).

No live model API was called. UI testing is not applicable to the Terraform,
package or MCP changes because they ship CLI and stdio flows. The Registry's
authenticated publishing UI is not exercised by the agent. GitHub Actions was
not started.

## v0.6.0 — 17 November 2026

Verified locally on Windows with Terraform 1.15.7 and Python 3.13. The locked
providers are Mastercard REST API 2.0.1, Modus Agendi Claude Managed Agents
1.1.0, and the official Google provider 8.11.0. Signed checksums were verified and recorded for Windows amd64 and Linux
amd64. Provider lifecycle fixtures ran on Windows. Container checks additionally
ran on Linux amd64 in the Docker VM and Linux arm64 under emulation, with Python
3.13.18 and Terraform 1.15.7 bundled into the images.

| Check | Result |
| --- | --- |
| `terraform fmt -check -recursive` | Passed |
| `terraform validate` | Passed |
| `terraform test` | 30 passed |
| `python tests/integration.py` | 5 passed |
| `python tests/google_integration.py` | 1 passed |
| `python tests/frontier_integration.py` | 2 passed |
| MCP integration suite over real stdio | 10 passed from the installed wheel; containers exercised separately |
| Linux amd64 container runtime and offline stdio | 2 passed |
| Linux arm64 container runtime and offline stdio, under emulation | 2 passed |
| PowerShell and Linux shell installers against real image archives | Passed |
| Both installers reject corrupted downloads before loading, including CRLF manifests | Passed |
| Validate MCP-generated Terraform configurations for all 14 implemented backends | Passed |
| Wheel build and inspection | Passed; exactly 8 whitelisted source data assets |
| Frozen dependency lock check | Passed |
| Ruff check of the package, integration suites and packaging tool | Passed |
| Eight unchanged Terraform examples | Previously verified in v0.3.0 |
| Local Markdown links and manual-only workflow configuration | Passed |

The repository rename preserved its GitHub database identity, private visibility,
all five existing tags and every v0.5.0 release asset ID, size and SHA-256 digest.
The previous Git URL redirects to `Tunet-xyz/agent_frame`. Terraform modules,
provider declarations, lock file and catalogue are unchanged from v0.5.0.
Canonical package, command, server, resource and container identities use
AgentFrame; compatibility checks exercise the previous Python launcher, console
command and resource URIs against the same implementation.

The integration checks run the installed providers and actual Terraform CLI
against local HTTP contract fixtures. They cover create, in-place update, no-op
plans, individual and complete metadata removal, empty instructions, remote
edits, imports, OpenAI external deletion/recreation, Claude archival reporting,
destroy, permission-error recovery, saved-plan/state credential exclusion,
credential redaction from CLI output, and independent single-vendor credentials.

Mistral checks exercise its PATCH endpoint and empty 204 deletion response. The
Google check uses the real provider's native resource against a local API with
long-running-operation responses and server defaults, including ADK config,
runtime identity, imports, external deletion, drift, and non-authoritative labels.
Grok's provider-free definition applies in the module suite without credentials
or an inference request. Catalogue and new-vendor definition contracts are also
covered.

The frontier checks apply all nine reviewed inference profiles, the dedicated
Muse entry point, and custom Chat Completions/Responses endpoints. They check
native tool schemas and instruction roles, Qwen's required workspace endpoint,
runtime-supplied input, and validation of unsupported profiles, credentials,
conversation state and URL userinfo. Catalogue discovery distinguishes these
definitions from remote resources.

The new CLI suite initializes against an empty provider mirror without a direct
registry fallback. It verifies saved-plan application, no resources in plan or
state, exclusion of unused fake environment credentials, endpoint changes without
a definition fingerprint change, runtime fingerprints, cleared instructions,
model updates, no-op plans and destroy. It makes no inference requests. Source
links and local catalogue paths were checked; the manual-only workflow includes
the new suite and was not dispatched.

The MCP suite starts actual client/server subprocesses from another directory
with spaces, including legacy protocol negotiation and the console entry point.
It checks four structured-output tools and four advertised resources (two
canonical resources and two legacy aliases), every inference
backend, a custom endpoint, concurrent compilation, missing Terraform, invalid
inputs and recovery. Generated configurations for all implemented backends
initialize and validate against a local provider mirror. Only a provider-free
configuration is applied to test that template-looking prompt text stays literal.

The built wheel was installed without editable source imports and the MCP suite
passed again using its bundled catalogue and Terraform files. Its distribution
metadata is `AgentFrame`, its import namespace is `agent_frame`, and both console
entry points are included. The package pins
the official MCP Python SDK 2.3.0; its uv lock resolves 31 packages, including
the project. Wheel contents exclude state, variable files, caches and credentials.
Initial testing found missing structured output schemas and an AnyIO test-client
cleanup issue; both were fixed before the successful runs.

Both architecture images run as UID/GID 10001, include Terraform and its upstream
license, and contain exactly the eight expected source assets. The container
suite uses a read-only root, no network, dropped capabilities and a 64 MB
temporary filesystem. It compiles all ten named inference backends and a custom
endpoint, checks literal instructions and error recovery, and renders a remote
OpenAI configuration without applying it. No host source or credentials are
mounted into the MCP server.

The PowerShell installer was exercised in PowerShell 7 and Windows PowerShell;
the shell installer ran in an ephemeral official Linux Docker CLI helper against
the same local engine. Both loaded the verified archive and created the expected
client alias. Corrupt downloads were rejected before loading. Both installers
also loaded the original v0.5.0 archive using its historical name and created the
new AgentFrame alias. The renamed checkout exposed CRLF shell-script endings;
the script now uses LF and a Git attribute preserves that across Windows clones.

Image bases are digest-pinned and the build context is an allowlist. The optional
GHCR publishing workflow is manual-only and was not started. Terraform Registry
requirements were checked against HashiCorp documentation; module publication
and account connection remain pending the owner's visibility/registry choice.
No public repository, custom provider registration or HCP organization was created.

Fixtures use fake keys, inherit no vendor credentials, and use a local provider
mirror after initialization. No live vendor agents were created or modified.
Account permissions, model availability, and all vendor-side validation of
nested tool definitions remain unverified against live APIs.

UI testing is not applicable: this repository ships Terraform modules, CLI
examples and a stdio MCP server, with no graphical application. The affected CLI
and MCP flows were exercised with real providers and client/server processes.
GitHub Actions was not run; its only trigger is
`workflow_dispatch`, which an agent must never invoke.

## Verified implementation findings

The extension adds portable definitions, a Grok Responses template, a reusable
REST profile, a Mistral adapter, and a capability catalogue. Mistral's stable
common handle leaves version null because the REST provider's computed response
could lag an update. The Google adapter requires min_instances >= 1 because the
pinned provider omitted zero in a create payload, producing a perpetual diff
against the documented server default. Both cases are covered by the completed
checks. Python lint, catalogue paths, documentation links, ADK method data, and
the manual-only workflow check pass. No live vendor account or GitHub Actions
workflow was used.

The v0.3.0 extension adds Meta Muse, DeepSeek, Qwen, Kimi, GLM, MiniMax, Cohere,
NVIDIA and OpenRouter definitions without adding provider dependencies to existing
entry points. Model IDs remain caller-selected. Meta-hosted Muse uses Responses;
existing self-hosted Muse Spark Open/Glimmer servers can use a compatible custom
profile. Those paths configure application artifacts, not cloud deployments.
