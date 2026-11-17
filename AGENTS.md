# AgentFrame Terraform release export

This checkout is generated from Tunet-xyz/agent_frame; SOURCE.json records its source and file hashes.
Make implementation changes upstream, then export a new tested release. Preserve unrelated work.
Verify with terraform fmt -check -recursive, terraform init -backend=false -lockfile=readonly,
terraform validate, terraform test, and the three Python CLI integration suites in tests/.
Use local fixtures and fake keys. There is no graphical UI or MCP package in this export.
Never start, rerun or enable GitHub Actions. Keep authentication non-interactive.
