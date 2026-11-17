# AgentFrame container distribution

The AgentFrame MCP container includes Python 3.13, the locked MCP dependencies, Terraform
1.15.7 and the provider-free source assets. Users need a Linux Docker engine;
they do not need host Python, uv, Terraform or model API keys. Docker Desktop
on Windows and macOS runs these Linux images.

Versioned `linux/amd64` and `linux/arm64` image archives are distributed through
the repository's public GitHub Releases with a `SHA256SUMS` file. Downloads
require no GitHub account or package-registry credential. The files are Docker
image archives, compressed with gzip;
[Docker loads them directly](https://docs.docker.com/reference/cli/docker/image/load/).

Existing releases retain their historical filenames. The current installers
recognize those names when explicitly selecting an older version; see
[the AgentFrame migration guide](migration.md).

## Install a prebuilt image

With the repository checked out:

```powershell
# Windows PowerShell
./tools/install-container.ps1
```

```sh
# Linux or macOS
sh tools/install-container.sh
```

The installer detects the Docker engine's architecture, downloads the matching
v0.6.1 archive and checksums, verifies its SHA-256, loads it and creates the
local `agent-frame-mcp:0.6.1` alias. It never starts an authentication flow.
The installers are also attached to the release, so a checkout is optional:

```powershell
Invoke-WebRequest -UseBasicParsing https://github.com/Tunet-xyz/agent_frame/releases/download/v0.6.1/install-container.ps1 -OutFile install-container.ps1
./install-container.ps1
```

On Linux/macOS, download `install-container.sh` from the release instead and run
it with `sh`. The shell installer uses `curl` or `wget` for HTTPS downloads.
You may also download the archive and checksum file yourself, then pass their
directory as `-ArchiveDirectory PATH` in PowerShell or the second shell-script
argument (`sh tools/install-container.sh 0.6.1 PATH`).

## MCP client configuration

After installing the image, configure the client's stdio command:

```json
{
  "mcpServers": {
    "agent-frame": {
      "command": "docker",
      "args": [
        "run", "--rm", "-i", "--read-only", "--network", "none",
        "--cap-drop", "ALL", "--security-opt", "no-new-privileges",
        "--tmpfs", "/tmp:rw,noexec,nosuid,size=64m,mode=1777",
        "agent-frame-mcp:0.6.1"
      ]
    }
  }
}
```

Use `-i` and leave off `-t`: the MCP host needs ordinary stdin/stdout pipes.
The image runs as UID/GID 10001, uses a read-only root, and only needs writable
temporary storage. No host directories, Docker socket or credentials are mounted
into the server. Definition compilation works with networking disabled.
The tools and behavior are described in [MCP setup](mcp.md).

## Build and verify locally

```sh
docker build --tag agent-frame-mcp:0.6.1 .
MCP_CONTAINER_IMAGE=agent-frame-mcp:0.6.1 uv run --frozen python tests/container_integration.py
```

For release maintainers, the packaging command builds and tests both Linux
architectures, then exports compressed image archives and checksums in `dist/`:

```sh
uv run --frozen python tools/package_containers.py
```

Buildx needs support for the target architecture, either native or through
emulation. Docker Desktop provides the configured local builder; the manual
publishing workflow configures QEMU on its runner. Base images are pinned by
digest. Dependencies use the frozen uv lock, and the final image contains an
installed wheel and Terraform binary, with the upstream Terraform license.
The Docker build context is an allowlist excluding state, keys and local caches.

## Optional GHCR publication

`.github/workflows/publish-container.yml` is manual-only. A user can start it
for an existing version tag to test both architectures and publish a multi-platform
image at `ghcr.io/tunet-xyz/agent-frame-mcp:VERSION` using the repository's
workflow token. Agents must never start or rerun it.

That registry image is available only after a successful user-started publish;
the initial distribution uses the GitHub Release downloads above. GHCR package
visibility remains governed by GitHub settings; public GitHub Release archives
are available independently of that workflow.
