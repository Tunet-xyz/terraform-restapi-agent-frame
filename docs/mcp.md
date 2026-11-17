# AgentFrame MCP server

The AgentFrame `agent-frame-mcp` server makes the shared agent catalogue and
Terraform definitions available to MCP clients. It uses the
[official Python MCP SDK](https://github.com/modelcontextprotocol/python-sdk),
pinned to 2.3.0, and communicates over local stdio. The package version is 0.6.1.

## Install and launch

Use Python 3.11 or newer. From the checked-out repository:

```shell
uv sync --frozen
uv run --frozen agent-frame-mcp
```

The server waits for an MCP client on stdin; silence on startup is expected.
It writes protocol messages to stdout and diagnostics to stderr. It opens no
HTTP listener. The lock file includes dependency versions and package hashes.

Terraform 1.10 or newer must be on the server process's `PATH` to compile
definitions. Catalogue discovery and Terraform configuration generation work
without Terraform. No vendor API keys, ADC, GitHub credentials or cloud account
are needed to run the server or compile an inference definition.

The package is MIT-licensed and has not been published to PyPI. Build a wheel with
`uv build --wheel` if needed. The wheel includes a fixed whitelist of the
catalogue and provider-free Terraform source files. It runs without the original
checkout; the consuming application still needs Terraform for compilation.

## Client configuration

After `uv sync --frozen`, point your client's stdio configuration at the virtual
environment's **absolute** Python executable. For clients using `mcpServers`:

```json
{
  "mcpServers": {
    "agent-frame": {
      "command": "/absolute/path/to/agent_frame/.venv/bin/python",
      "args": ["-m", "agent_frame"]
    }
  }
}
```

On Windows, use `C:/path/to/agent_frame/.venv/Scripts/python.exe` instead.
The launch command works from another working directory, including paths with
spaces. Ensure the client's environment can find Terraform when using the
compiler. See the [SDK's stdio host guide](https://py.sdk.modelcontextprotocol.io/get-started/real-host/)
for host-specific configuration formats. The repository supplies the server;
it does not alter your existing MCP client configuration.

## Tools

| Tool | Purpose | Terraform needed |
| --- | --- | --- |
| `list_backends` | Return the shared capability catalogue, optionally filtering by management type | No |
| `get_backend` | Return one backend's module, lifecycle capabilities, official docs and inference profile | No |
| `render_terraform_configuration` | Generate reviewable `main.tf.json` for any implemented backend | No |
| `build_inference_agent` | Compile a Grok, frontier or custom agent definition and runtime template with the existing Terraform module | Yes |

The tools return structured JSON and are annotated as read-only with a closed
set of inputs and bundled sources. They do not call model APIs or run a cloud
deployment. The configuration tool returns file contents for the client to
review and save; it does not write into your project. AWS Bedrock and Azure
Foundry catalogue entries point to external providers and documentation because
this repository has no dedicated adapter for those entries.

Two JSON resources expose the same underlying data:

- `agent-frame://catalog`
- `agent-frame://inference-profiles`

The previous command, Python namespace and resource URIs remain available as
deprecated compatibility aliases in this release. See [the migration guide](migration.md).

## Build a definition

Call `build_inference_agent` with:

```json
{
  "spec": {
    "backend": "muse",
    "name": "Review assistant",
    "model": "YOUR_ACCOUNT_ENABLED_MUSE_MODEL",
    "instructions": "Help the team review changes.",
    "metadata": {"team": "platform"},
    "options": {"settings_json": "{\"temperature\":0.2}"}
  }
}
```

The result contains the same `agent`, `definition`, `fingerprint`, `capabilities`
and `runtime` values as Terraform, plus `runtime_fingerprint`. The remote
`agent.id` is null. Model IDs are supplied by the caller; the tool does not
check live model availability or choose a moving latest alias.

Supported inference backends are Muse, DeepSeek, Qwen, Kimi, GLM, MiniMax,
Cohere, NVIDIA, OpenRouter and Grok. Qwen needs `options.base_url` with its
workspace and region endpoint. `options.tools_json` and `options.settings_json`
use the selected vendor's native JSON format. The
[frontier reference](frontier.md) explains protocols, tool schemas and key names.
Grok retains its existing Terraform runtime format and continuation policy from
[the extension reference](extending.md).

For an existing compatible server, use `backend = "custom"` and supply:

```json
{
  "spec": {
    "backend": "custom",
    "name": "Local model",
    "model": "YOUR_SERVED_MODEL_ID",
    "custom_profile": {
      "vendor": "meta",
      "protocol": "chat_completions",
      "base_url": "http://127.0.0.1:8000/v1"
    }
  }
}
```

Custom profiles may instead use `responses`, set `instruction_role` to
`system` or `developer`, and name a runtime credential in `api_key_env`.
The server exports the endpoint and template; it never connects to that endpoint.

## Generate Terraform for a remote agent

Call `render_terraform_configuration` with the same `spec` shape, for example
`backend = "openai"`, `"anthropic"`, `"mistral"` or `"gemini"`. It returns a
`configuration_json` string, the suggested filename, credential setup notes and
the remote-lifecycle capability. Module sources are pinned to this release's
`v0.6.1` tag.

OpenAI and Mistral configurations declare the locked REST provider and an
ephemeral, sensitive `api_key` input; supply `TF_VAR_api_key` separately when
running Terraform. Claude uses `ANTHROPIC_API_KEY`. Gemini uses ADC or workload
identity and requires `options.project`, `options.region` and
`options.service_account` for an existing runtime identity. The generated
configuration does not include any credential value.

The tool also renders provider-free backends. Review and save the generated
configuration in the intended workspace, then run `terraform init`, `plan` and
`apply` yourself or through your normal infrastructure workflow. Downloading the
public module requires no GitHub authentication. The server itself
does not need Git access for discovery, rendering or definition compilation.

## Isolation and limits

Definition compilation copies only known provider-free module files into a
unique system temporary directory. It uses an empty provider mirror with no
registry fallback and strips vendor credentials and caller Terraform settings
from child processes. It never operates on the caller's state or workspace.
Each Terraform command has a 20-second timeout; the temporary workspace is
removed when the request finishes. Concurrent requests use separate workspaces.

Definitions are passed through a JSON variable file so text containing `${...}`
remains literal. Generated Terraform JSON escapes template syntax for the same
reason. The server accepts no shell command, module URL or arbitrary file path.

Use `options.api_key_env` for an environment **name**, never the credential
value. Keep secrets out of tool arguments, instructions, metadata, tools and
settings: MCP clients may retain tool history, and Terraform validation errors
can quote submitted values. Runtime input, conversation history, tool execution,
streaming, credentials and inference remain the application's responsibility.

## Verification

```shell
terraform init -backend=false -input=false -lockfile=readonly
uv sync --frozen
uv run --frozen python tests/mcp_integration.py
uv build --wheel
```

The suite uses actual stdio client/server subprocesses, including legacy
protocol negotiation, resources and tool discovery, structured results,
concurrent definitions, missing Terraform, invalid inputs and recovery. It
compiles every inference backend without vendor access and validates generated
Terraform for all implemented backends using the repository's local provider
mirror. Template-looking instructions are checked through an actual Terraform
apply of a provider-free module. No remote resource is applied by these tests.
The server ships no graphical UI; its user-facing flow is the MCP protocol.
