"""Exercise real Terraform providers against contract fixtures, using fake keys.

Run terraform init in the repository first. No vendor API or registry is contacted
by this script: provider installation uses the initialized local filesystem mirror.
"""

from __future__ import annotations

import json
import os
import re
import subprocess
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

ROOT = Path(__file__).resolve().parents[1]
TIMESTAMP = "2026-11-16T10:00:00Z"
FIXTURE_SECRETS = ("fixture-openai", "fixture-anthropic", "fixture-mistral")


class AgentAPI(ThreadingHTTPServer):
    def __init__(self):
        super().__init__(("127.0.0.1", 0), Handler)
        self.agents: dict[str, dict] = {}
        self.events: list[tuple[str, str, str]] = []
        self.next_id = 1
        self.deny_next_write = False

    @property
    def url(self):
        return f"http://127.0.0.1:{self.server_port}"


class Handler(BaseHTTPRequestHandler):
    server: AgentAPI

    def log_message(self, *args):
        pass

    def reply(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def authenticate(self):
        if self.headers.get("Authorization") == "Bearer fixture-openai":
            if self.headers.get("OpenAI-Beta") != "agents=v1":
                self.reply(400, {"error": {"message": "missing OpenAI beta header"}})
                return None
            vendor = "openai"
        elif self.headers.get("Authorization") == "Bearer fixture-mistral":
            if self.headers.get("OpenAI-Beta"):
                self.reply(400, {"error": {"message": "OpenAI headers sent to Mistral"}})
                return None
            vendor = "mistral"
        elif self.headers.get("x-api-key") == "fixture-anthropic":
            if "managed-agents-2026-04-01" not in self.headers.get("anthropic-beta", ""):
                self.reply(400, {"type": "error", "error": {"type": "invalid_request_error", "message": "missing Claude beta header"}})
                return None
            vendor = "anthropic"
        else:
            self.reply(401, {"error": {"message": "fixture requires fake credentials"}})
            return None
        path = urlsplit(self.path).path
        if not path.startswith("/v1/agents"):
            self.reply(404, {"error": {"message": "unexpected endpoint"}})
            return None
        self.server.events.append((vendor, self.command, path))
        return vendor

    def do_GET(self):
        vendor = self.authenticate()
        if vendor is None:
            return
        agent = self.server.agents.get(urlsplit(self.path).path.rsplit("/", 1)[-1])
        if agent is None or agent["vendor"] != vendor:
            self.reply(404, {"type": "error", "error": {"type": "not_found_error", "message": "agent not found"}})
            return
        self.reply(200, agent["body"])

    def do_POST(self):
        vendor = self.authenticate()
        if vendor is None:
            return
        raw = self.rfile.read(int(self.headers.get("Content-Length", 0)))
        data = json.loads(raw) if raw else {}
        path = urlsplit(self.path).path
        if self.server.deny_next_write:
            self.server.deny_next_write = False
            self.reply(403, {"type": "error", "error": {"type": "permission_error", "message": "fixture permission denied"}})
            return
        if path.endswith("/archive"):
            agent_id = path.split("/")[-2]
            self.server.agents[agent_id]["body"]["archived_at"] = TIMESTAMP
            self.reply(200, self.server.agents[agent_id]["body"])
            return

        creating = path == "/v1/agents"
        if vendor == "mistral" and self.command != ("POST" if creating else "PATCH"):
            self.reply(405, {"error": {"message": "Mistral requires PATCH for updates"}})
            return
        if creating:
            agent_id = f"agent_{vendor}_{self.server.next_id}"
            self.server.next_id += 1
            if vendor == "openai":
                body = {"id": agent_id, "object": "agent", "created_at": 1794823200,
                        "updated_at": 1794823200, "async": False, "time_awareness": True,
                        "multi_agent": {}, "text": {"format": {"type": "text"}},
                        "compaction": None, "experimental": None}
            elif vendor == "mistral":
                body = {
                    "id": agent_id, "object": "agent", "version": 0, "versions": [],
                    "created_at": TIMESTAMP, "updated_at": TIMESTAMP,
                    "owner_id": "fixture-owner", "source": "api", "deployment_chat": False,
                    "completion_args": {"temperature": 0.7}, "guardrails": None, "handoffs": None,
                }
            else:
                body = {
                    "id": agent_id, "type": "agent", "version": 0,
                    "created_at": TIMESTAMP, "updated_at": TIMESTAMP,
                    "archived_at": None, "description": None, "system": None,
                    "mcp_servers": [], "skills": [], "tools": [],
                    "multiagent": None, "metadata": {},
                    "execution_identity": {"type": "service_account"},
                }
            self.server.agents[agent_id] = {"vendor": vendor, "body": body}
        else:
            agent_id = path.rsplit("/", 1)[-1]
            if agent_id not in self.server.agents:
                self.reply(404, {"error": {"message": "agent not found"}})
                return
            body = self.server.agents[agent_id]["body"]

        if vendor in ("openai", "mistral"):
            allowed = {"name", "model", "instructions", "metadata", "tools"}
            allowed |= {"reasoning", "service_tier"} if vendor == "openai" else {"description"}
            if set(data) - allowed:
                self.reply(400, {"error": {"message": "unknown agent field: " + ",".join(sorted(set(data) - allowed))}})
                return
            body.update(data)
            if vendor == "openai" and body.get("reasoning") is None:
                body["reasoning"] = {"effort": None}
            if vendor == "mistral":
                body["version"] += 1
                body["versions"].append(body["version"])
        else:
            if not creating and data.get("version", body["version"]) != body["version"]:
                self.reply(409, {"type": "error", "error": {"type": "conflict_error", "message": "stale agent version"}})
                return
            data.pop("version", None)
            metadata = data.pop("metadata", {})
            for key, value in metadata.items():
                if value is None:
                    body["metadata"].pop(key, None)
                else:
                    body["metadata"][key] = value
            if "model" in data:
                model = data["model"]
                if isinstance(model, str):
                    model = {"id": model}
                model.pop("type", None)
                model.setdefault("effort", {"type": "high"})
                if isinstance(model["effort"], str):
                    model["effort"] = {"type": model["effort"]}
                data["model"] = model
            body.update(data)
            body["version"] += 1
        self.reply(200, body)

    def do_PATCH(self):
        self.do_POST()

    def do_DELETE(self):
        vendor = self.authenticate()
        if vendor is None:
            return
        if vendor not in ("openai", "mistral"):
            self.reply(405, {"error": {"message": "Claude archives agents"}})
            return
        agent_id = urlsplit(self.path).path.rsplit("/", 1)[-1]
        self.server.agents.pop(agent_id, None)
        if vendor == "mistral":
            self.send_response(204)
            self.end_headers()
            return
        self.reply(200, {"id": agent_id, "object": "agent.deleted", "deleted": True})


class Terraform:
    def __init__(self, folder, server, vendor, direct=False):
        self.folder = Path(folder)
        self.server = server
        self.vendor = vendor
        self.env = {
            key: value for key, value in os.environ.items()
            if not key.startswith(("OPENAI_", "ANTHROPIC_", "MISTRAL_", "XAI_", "GROK_", "REST_API_", "TF_VAR_", "TF_LOG", "TF_CLI_ARGS", "TF_PLUGIN_CACHE"))
        }
        self.env.update({"TF_INPUT": "0", "TF_IN_AUTOMATION": "1", "CHECKPOINT_DISABLE": "1"})
        if vendor == "anthropic" or not direct:
            self.env["ANTHROPIC_API_KEY"] = "fixture-anthropic"
        self.env["ANTHROPIC_BASE_URL"] = server.url
        mirror = (ROOT / ".terraform" / "providers").as_posix()
        config_file = self.folder / "terraform.tfrc"
        config_file.write_text(
            "provider_installation {\n  filesystem_mirror {\n"
            f"    path = {json.dumps(mirror)}\n"
            '    include = ["registry.terraform.io/*/*"]\n  }\n}\n', encoding="utf-8"
        )
        self.env["TF_CLI_CONFIG_FILE"] = str(config_file)
        config = {
            "terraform": {"required_providers": {
                "restapi": {"source": "Mastercard/restapi", "version": "~> 2.0.1"},
                "claude": {"source": "modus-agendi/anthropic-claude-managed-agents", "version": "~> 1.1.0"},
            }},
            "provider": {
                "restapi": {"uri": server.url + "/v1", "write_returns_object": True,
                            "headers": {"Authorization": "Bearer ${var.openai_api_key}", "OpenAI-Beta": "agents=v1"}},
                "claude": {"base_url": server.url},
            },
            "variable": {
                "openai_api_key": {"type": "string", "sensitive": True, "ephemeral": True},
                "name": {"type": "string", "default": "Fixture agent"},
                "instructions": {"type": "string", "default": "Help the user."},
                "metadata": {"type": "map(string)", "default": {"team": "test", "obsolete": "remove-me"}},
                "tools_json": {"type": "string", "default": "[]"},
            },
            "module": {"agent": {
                "source": Path(os.path.relpath(ROOT, self.folder)).as_posix(), "vendor": vendor,
                "providers": {"restapi": "restapi", "claude": "claude"},
                "name": "${var.name}",
                "model": "gpt-6-astra" if vendor == "openai" else "claude-sonnet-4-6",
                "instructions": "${var.instructions}", "metadata": "${var.metadata}",
                "openai": {"tools_json": "${var.tools_json}"},
            }},
            "output": {"agent": {"value": "${module.agent.agent}"}},
        }
        self.env["TF_VAR_openai_api_key"] = "fixture-mistral" if vendor == "mistral" else "fixture-openai"
        if direct:
            selected = "claude" if vendor == "anthropic" else "restapi"
            config["terraform"]["required_providers"] = {selected: config["terraform"]["required_providers"][selected]}
            config["provider"] = {selected: config["provider"][selected]}
            module = config["module"]["agent"]
            module["source"] += "/modules/" + vendor
            module.pop("vendor")
            module["providers"] = {selected: selected}
            module.pop("openai")
            if vendor in ("openai", "mistral"):
                module["options"] = {"tools_json": "${var.tools_json}"}
                if vendor == "mistral":
                    config["provider"]["restapi"]["headers"].pop("OpenAI-Beta")
            else:
                config["variable"].pop("openai_api_key")
                self.env.pop("TF_VAR_openai_api_key")
        (self.folder / "main.tf.json").write_text(json.dumps(config), encoding="utf-8")
        lock = (ROOT / ".terraform.lock.hcl").read_text(encoding="utf-8")
        sources = {item["source"].lower() for item in config["terraform"]["required_providers"].values()}
        lock = "\n\n".join(
            match.group(0) for match in re.finditer(r'provider "registry\.terraform\.io/([^\"]+)" \{.*?^\}', lock, flags=re.DOTALL | re.MULTILINE)
            if match.group(1).lower() in sources
        ) + "\n"
        if not lock.strip():
            raise AssertionError("The repository lock file is missing the selected provider.")
        (self.folder / ".terraform.lock.hcl").write_text(lock, encoding="utf-8")
        self.run("init", "-backend=false", "-lockfile=readonly")

    def run(self, *args, codes=(0,)):
        command = ["terraform", *args, "-no-color"]
        # `output -json` and `state rm` do not accept -no-color.
        if args[0] in ("output", "state"):
            command.pop()
        result = subprocess.run(command, cwd=self.folder, env=self.env,
                                capture_output=True, text=True, encoding="utf-8", timeout=120, check=False)
        if any(secret in result.stdout + result.stderr for secret in FIXTURE_SECRETS):
            raise AssertionError("A provider exposed a fixture credential in CLI output.")
        if result.returncode not in codes:
            raise AssertionError(f"{' '.join(command)} failed ({result.returncode}):\n{result.stdout}\n{result.stderr}")
        return result

    def apply(self):
        self.run("apply", "-auto-approve", "-input=false")
        return json.loads(self.run("output", "-json", "agent").stdout)

    def plan(self, changed):
        return self.run("plan", "-input=false", "-detailed-exitcode", codes=(2,) if changed else (0,))

    def variables(self, **values):
        (self.folder / "test.auto.tfvars.json").write_text(json.dumps(values), encoding="utf-8")


class LifecycleTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        if not (ROOT / ".terraform" / "providers").exists():
            raise RuntimeError("Run terraform init -backend=false in the repository first.")

    def setUp(self):
        self.server = AgentAPI()
        self.thread = threading.Thread(target=self.server.serve_forever, daemon=True)
        self.thread.start()
        self.temp = tempfile.TemporaryDirectory(prefix="agent_frame-")
        # Cleanup is confined to the unique system-temp folder this test created.
        self.assertTrue(Path(self.temp.name).resolve().is_relative_to(Path(tempfile.gettempdir()).resolve()))

    def tearDown(self):
        self.server.shutdown()
        self.server.server_close()
        self.thread.join(timeout=5)
        self.temp.cleanup()

    def lifecycle(self, vendor):
        terraform = Terraform(self.temp.name, self.server, vendor, direct=vendor == "mistral")
        terraform.plan(changed=True)
        terraform.run("plan", "-input=false", "-out=saved.tfplan")
        saved = terraform.run("show", "-json", "saved.tfplan").stdout
        self.assertNotIn("fixture-openai", saved)
        self.assertNotIn("fixture-anthropic", saved)
        self.assertNotIn("fixture-mistral", saved)
        self.server.deny_next_write = True
        failure = terraform.run("apply", "-auto-approve", "-input=false", codes=(1,))
        self.assertIn("403", failure.stdout + failure.stderr)
        self.assertEqual(len(self.server.agents), 0)
        handle = terraform.apply()
        agent_id = handle["id"]
        self.assertEqual(handle["vendor"], vendor)
        self.assertEqual(len(self.server.agents), 1)
        terraform.plan(changed=False)

        state = (terraform.folder / "terraform.tfstate").read_text(encoding="utf-8")
        self.assertNotIn("fixture-openai", state)
        self.assertNotIn("fixture-anthropic", state)
        self.assertNotIn("fixture-mistral", state)

        # Removing a metadata key must clear it remotely. Both APIs are tested:
        # OpenAI replaces metadata; Claude merges keys and needs explicit nulls.
        terraform.variables(name="Updated agent", instructions="", metadata={"team": "updated"})
        terraform.plan(changed=True)
        self.assertEqual(terraform.apply()["id"], agent_id)
        body = self.server.agents[agent_id]["body"]
        self.assertEqual(body["name"], "Updated agent")
        self.assertEqual(body["metadata"], {"team": "updated"})
        self.assertEqual(body["system" if vendor == "anthropic" else "instructions"], None if vendor == "anthropic" else "")
        terraform.plan(changed=False)

        # Refresh must notice out-of-band edits and the next apply must repair them.
        body["name"] = "External edit"
        body["metadata"]["external"] = "remove-me"
        if vendor == "anthropic":
            body["version"] += 1
        terraform.plan(changed=True)
        terraform.apply()
        self.assertEqual(body["name"], "Updated agent")
        self.assertEqual(body["metadata"], {"team": "updated"})
        terraform.plan(changed=False)

        # Import must adopt the same agent and settle to a no-op after reconciliation.
        addresses = {
            "openai": "module.agent.module.openai[0].restapi_object.this",
            "anthropic": "module.agent.module.anthropic[0].claude-managed-agents_agent.this",
            "mistral": "module.agent.module.backend.restapi_object.this",
        }
        address = addresses[vendor]
        identifier = agent_id if vendor == "anthropic" else "/agents/" + agent_id
        terraform.run("state", "rm", address)
        terraform.run("import", "-input=false", address, identifier)
        imported = terraform.apply()
        self.assertEqual(imported["id"], agent_id)
        self.assertEqual(len(self.server.agents), 1)
        terraform.plan(changed=False)

        # OpenAI supports deletion. Claude exposes archival as a terminal status.
        terraform.variables(name="Updated agent", instructions="", metadata={})
        terraform.apply()
        self.assertEqual(body["metadata"], {})
        terraform.plan(changed=False)

        # Empty metadata must also clear Claude's patch-based metadata bag.
        if vendor != "anthropic":
            self.server.agents.pop(agent_id)
            terraform.plan(changed=True)
            new_id = terraform.apply()["id"]
            self.assertNotEqual(new_id, agent_id)
        else:
            body["archived_at"] = TIMESTAMP
            terraform.plan(changed=True)
            archived = terraform.apply()
            self.assertEqual(archived["id"], agent_id)
            self.assertTrue(archived["archived"])
            new_id = agent_id
        terraform.plan(changed=False)
        terraform.run("destroy", "-auto-approve", "-input=false")
        if vendor != "anthropic":
            self.assertNotIn(new_id, self.server.agents)
            self.assertIn((vendor, "DELETE", "/v1/agents/" + new_id), self.server.events)
        else:
            self.assertIsNotNone(self.server.agents[new_id]["body"]["archived_at"])
            self.assertIn((vendor, "POST", "/v1/agents/" + new_id + "/archive"), self.server.events)
        # The unused platform must receive no API traffic.
        self.assertEqual({event[0] for event in self.server.events}, {vendor})

    def test_openai_lifecycle(self):
        self.lifecycle("openai")

    def test_claude_lifecycle(self):
        self.lifecycle("anthropic")

    def test_mistral_lifecycle(self):
        self.lifecycle("mistral")
        self.assertTrue(any(event[1] == "PATCH" for event in self.server.events))

    def test_openai_entrypoint_needs_no_claude_credentials(self):
        terraform = Terraform(self.temp.name, self.server, "openai", direct=True)
        self.assertNotIn("ANTHROPIC_API_KEY", terraform.env)
        terraform.apply()
        terraform.plan(changed=False)
        terraform.run("destroy", "-auto-approve", "-input=false")

    def test_claude_entrypoint_needs_no_openai_credentials(self):
        terraform = Terraform(self.temp.name, self.server, "anthropic", direct=True)
        self.assertNotIn("TF_VAR_openai_api_key", terraform.env)
        terraform.apply()
        terraform.plan(changed=False)
        terraform.run("destroy", "-auto-approve", "-input=false")


if __name__ == "__main__":
    unittest.main(verbosity=2)
