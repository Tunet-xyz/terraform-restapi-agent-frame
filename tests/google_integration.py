"""Exercise the real Google provider against a local Agent Engine contract API."""

from __future__ import annotations

import copy
import json
import os
import re
import tempfile
import threading
import unittest
from http.server import BaseHTTPRequestHandler, ThreadingHTTPServer
from pathlib import Path
from urllib.parse import urlsplit

from integration import ROOT, TIMESTAMP, Terraform

TOKEN = "fixture-google"
PARENT = "projects/fixture-project/locations/us-central1"


class GoogleAPI(ThreadingHTTPServer):
    def __init__(self):
        super().__init__(("127.0.0.1", 0), Handler)
        self.engines = {}
        self.operations = {}
        self.events = []
        self.next_id = 123456
        self.deny_next_write = False

    @property
    def url(self):
        return f"http://127.0.0.1:{self.server_port}"


class Handler(BaseHTTPRequestHandler):
    server: GoogleAPI

    def log_message(self, *args):
        pass

    def reply(self, status, payload):
        body = json.dumps(payload).encode()
        self.send_response(status)
        self.send_header("Content-Type", "application/json")
        self.send_header("Content-Length", str(len(body)))
        self.end_headers()
        self.wfile.write(body)

    def authorize(self):
        if self.headers.get("Authorization") != "Bearer " + TOKEN:
            self.reply(401, {"error": {"code": 401, "message": "fixture token required"}})
            return None
        path = urlsplit(self.path).path
        if not path.startswith("/v1/" + PARENT + "/"):
            self.reply(404, {"error": {"code": 404, "message": "unexpected API path"}})
            return None
        self.server.events.append((self.command, path))
        return path.removeprefix("/v1/")

    def operation(self, resource):
        name = PARENT + "/operations/op-" + str(len(self.server.operations) + 1)
        operation = {"name": name, "done": True, "response": copy.deepcopy(resource)}
        self.server.operations[name] = operation
        self.reply(200, operation)

    def do_GET(self):
        path = self.authorize()
        if path is None:
            return
        value = self.server.operations.get(path) if "/operations/" in path else self.server.engines.get(path)
        if value is None:
            self.reply(404, {"error": {"code": 404, "status": "NOT_FOUND", "message": "engine not found"}})
            return
        self.reply(200, value)

    def do_POST(self):
        path = self.authorize()
        if path is None:
            return
        data = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
        if self.server.deny_next_write:
            self.server.deny_next_write = False
            self.reply(403, {"error": {"code": 403, "status": "PERMISSION_DENIED", "message": "fixture permission denied"}})
            return
        if path != PARENT + "/reasoningEngines":
            self.reply(405, {"error": {"code": 405, "message": "unexpected create path"}})
            return
        name = path + "/" + str(self.server.next_id)
        self.server.next_id += 1
        data.update({"name": name, "createTime": TIMESTAMP, "updateTime": TIMESTAMP})
        deployment = data.setdefault("spec", {}).setdefault("deploymentSpec", {})
        deployment.setdefault("minInstances", 1)
        deployment.setdefault("maxInstances", 100)
        deployment.setdefault("resourceLimits", {"cpu": "4", "memory": "4Gi"})
        self.server.engines[name] = data
        self.operation(data)

    def do_PATCH(self):
        path = self.authorize()
        if path is None:
            return
        data = json.loads(self.rfile.read(int(self.headers.get("Content-Length", 0))))
        self.server.engines[path].update(data)
        self.operation(self.server.engines[path])

    def do_DELETE(self):
        path = self.authorize()
        if path is None:
            return
        self.server.engines.pop(path, None)
        self.operation({})


class GoogleTerraform(Terraform):
    def __init__(self, folder, server):
        self.folder = Path(folder)
        self.env = {
            key: value for key, value in os.environ.items()
            if not key.startswith(("GOOGLE_", "GCLOUD_", "GCP_", "CLOUDSDK_", "OPENAI_", "ANTHROPIC_", "MISTRAL_", "XAI_", "REST_API_", "TF_VAR_", "TF_LOG", "TF_CLI_ARGS", "TF_PLUGIN_CACHE"))
        }
        self.env.update({"TF_INPUT": "0", "TF_IN_AUTOMATION": "1", "CHECKPOINT_DISABLE": "1", "TF_VAR_access_token": TOKEN})
        mirror = (ROOT / ".terraform/providers").as_posix()
        cli = self.folder / "terraform.tfrc"
        cli.write_text('provider_installation {\n filesystem_mirror {\n'
                       f' path = {json.dumps(mirror)}\n'
                       ' include = ["registry.terraform.io/hashicorp/google"]\n }\n}\n', encoding="utf-8")
        self.env["TF_CLI_CONFIG_FILE"] = str(cli)
        config = {
            "terraform": {"required_providers": {"google": {"source": "hashicorp/google", "version": "~> 8.11.0"}}},
            "provider": {"google": {
                "project": "fixture-project", "region": "us-central1",
                "access_token": "${var.access_token}", "vertex_ai_custom_endpoint": server.url + "/v1/",
            }},
            "variable": {
                "access_token": {"type": "string", "sensitive": True, "ephemeral": True},
                "name": {"type": "string", "default": "Fixture Gemini"},
                "model": {"type": "string", "default": "gemini-fixture-model"},
                "instructions": {"type": "string", "default": "Be helpful."},
                "metadata": {"type": "map(string)", "default": {"team": "test", "obsolete": "remove-me"}},
            },
            "module": {"agent": {
                "source": Path(os.path.relpath(ROOT / "modules/gemini", self.folder)).as_posix(),
                "providers": {"google": "google"}, "name": "${var.name}", "model": "${var.model}",
                "instructions": "${var.instructions}", "metadata": "${var.metadata}",
                "options": {"project": "fixture-project", "region": "us-central1", "service_account": "runtime@fixture-project.iam.gserviceaccount.com"},
            }},
            "output": {"agent": {"value": "${module.agent.agent}"}},
        }
        (self.folder / "main.tf.json").write_text(json.dumps(config), encoding="utf-8")
        lock = (ROOT / ".terraform.lock.hcl").read_text(encoding="utf-8")
        lock = next(match.group(0) for match in re.finditer(r'provider "registry\.terraform\.io/hashicorp/google" \{.*?^\}', lock, flags=re.DOTALL | re.MULTILINE))
        (self.folder / ".terraform.lock.hcl").write_text(lock + "\n", encoding="utf-8")
        self.run("init", "-backend=false", "-lockfile=readonly")

    def run(self, *args, codes=(0,)):
        result = super().run(*args, codes=codes)
        if TOKEN in result.stdout + result.stderr:
            raise AssertionError("A provider exposed the fixture token in CLI output.")
        return result


class GoogleLifecycleTests(unittest.TestCase):
    def test_native_adk_lifecycle(self):
        with tempfile.TemporaryDirectory(prefix="agent_frame-google-") as folder:
            self.assertTrue(Path(folder).resolve().is_relative_to(Path(tempfile.gettempdir()).resolve()))
            server = GoogleAPI()
            thread = threading.Thread(target=server.serve_forever, daemon=True)
            thread.start()
            try:
                terraform = GoogleTerraform(folder, server)
                terraform.plan(changed=True)
                terraform.run("plan", "-input=false", "-out=saved.tfplan")
                self.assertNotIn(TOKEN, terraform.run("show", "-json", "saved.tfplan").stdout)
                server.deny_next_write = True
                failed = terraform.run("apply", "-auto-approve", "-input=false", codes=(1,))
                self.assertIn("403", failed.stdout + failed.stderr)
                self.assertEqual(server.engines, {})
                handle = terraform.apply()
                agent_id = handle["id"]
                self.assertEqual(handle["vendor"], "google")
                body = server.engines[agent_id]
                config = body["spec"]["sourceCodeSpec"]["agentConfigSource"]["adkConfig"]["jsonConfig"]
                self.assertEqual(config["model"], "gemini-fixture-model")
                self.assertEqual(config["instruction"], "Be helpful.")
                terraform.plan(changed=False)
                self.assertNotIn(TOKEN, (Path(folder) / "terraform.tfstate").read_text())

                terraform.variables(name="Updated Gemini", instructions="", metadata={"team": "updated"})
                self.assertEqual(terraform.apply()["id"], agent_id)
                self.assertEqual(body["displayName"], "Updated Gemini")
                self.assertEqual(body["spec"]["sourceCodeSpec"]["agentConfigSource"]["adkConfig"]["jsonConfig"]["instruction"], "")
                self.assertNotIn("obsolete", body["labels"])
                terraform.plan(changed=False)

                body["displayName"] = "External edit"
                body["labels"]["outside"] = "keep-me"
                terraform.plan(changed=True)
                terraform.apply()
                self.assertEqual(body["displayName"], "Updated Gemini")
                self.assertEqual(body["labels"]["outside"], "keep-me")
                terraform.plan(changed=False)

                address = "module.agent.google_vertex_ai_reasoning_engine.this"
                terraform.run("state", "rm", address)
                terraform.run("import", "-input=false", address, agent_id)
                self.assertEqual(terraform.apply()["id"], agent_id)
                self.assertEqual(len(server.engines), 1)
                terraform.plan(changed=False)

                server.engines.pop(agent_id)
                terraform.plan(changed=True)
                new_id = terraform.apply()["id"]
                self.assertNotEqual(new_id, agent_id)
                terraform.run("destroy", "-auto-approve", "-input=false")
                self.assertEqual(server.engines, {})
                self.assertTrue(any(method == "PATCH" for method, _ in server.events))
                self.assertTrue(any(method == "DELETE" for method, _ in server.events))
            finally:
                server.shutdown()
                server.server_close()
                thread.join(timeout=5)


if __name__ == "__main__":
    unittest.main(verbosity=2)
