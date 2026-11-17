"""Exercise provider-free definitions through the actual Terraform CLI, offline.

No provider registry or vendor API is needed. The CLI configuration forbids
provider downloads so an accidental provider dependency fails initialization.
"""

from __future__ import annotations

import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROFILES = json.loads((ROOT / "modules/inference/profiles.json").read_text(encoding="utf-8"))["profiles"]


class FrontierCLI(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory(prefix="terraform-frontier-")
        self.folder = Path(self.temp.name)
        self.assertTrue(self.folder.resolve().is_relative_to(Path(tempfile.gettempdir()).resolve()))
        self.env = {
            key: value for key, value in os.environ.items()
            if not key.startswith(("TF_", "GOOGLE_", "AWS_", "AZURE_"))
            and not any(part in key.upper() for part in ("API_KEY", "API_TOKEN", "ACCESS_TOKEN"))
            and key not in ("CLOUDSDK_AUTH_CREDENTIAL_FILE_OVERRIDE", "ANTHROPIC_BASE_URL")
        }
        self.secrets = [f"fixture-unused-{name}-credential" for name in PROFILES]
        # Keys are deliberately available to the process, but no module may read them.
        self.env.update({profile["api_key_env"]: secret for profile, secret in zip(PROFILES.values(), self.secrets, strict=True)})
        self.env.update({"TF_IN_AUTOMATION": "1", "TF_INPUT": "0", "CHECKPOINT_DISABLE": "1"})
        (self.folder / "empty-mirror").mkdir()
        cli_config = self.folder / "offline.tfrc"
        cli_config.write_text(
            "provider_installation {\n  filesystem_mirror {\n"
            f'    path = {json.dumps((self.folder / "empty-mirror").as_posix())}\n'
            '    include = ["registry.terraform.io/*/*"]\n  }\n}\n', encoding="utf-8"
        )
        self.env["TF_CLI_CONFIG_FILE"] = str(cli_config)

    def tearDown(self):
        self.temp.cleanup()

    def run_tf(self, *args, codes=(0,)):
        result = subprocess.run(
            ["terraform", *args], cwd=self.folder, env=self.env,
            capture_output=True, text=True, encoding="utf-8", timeout=120, check=False,
        )
        self.assertFalse(any(secret in result.stdout + result.stderr for secret in self.secrets))
        self.assertIn(result.returncode, codes, result.stdout + result.stderr)
        return result.stdout

    def configure(self, source, **arguments):
        config = {
            "module": {"assistant": {
                "source": Path(os.path.relpath(ROOT / source, self.folder)).as_posix(), **arguments,
            }},
            "output": {key: {"value": "${module.assistant." + key + "}"} for key in (
                ("agents",) if source == "tests/fixtures/frontier" else
                ("agent", "definition", "fingerprint", "runtime_fingerprint", "runtime", "capabilities")
            )},
        }
        (self.folder / "main.tf.json").write_text(json.dumps(config), encoding="utf-8")

    def outputs(self):
        return {name: output["value"] for name, output in json.loads(self.run_tf("output", "-json")).items()}

    def assert_no_resources_or_credentials(self):
        state = json.loads((self.folder / "terraform.tfstate").read_text(encoding="utf-8"))
        self.assertEqual(state.get("resources", []), [])
        self.assertFalse(any(secret in json.dumps(state) for secret in self.secrets))

    def test_every_profile_applies_offline_without_providers(self):
        self.configure("tests/fixtures/frontier")
        self.run_tf("init", "-backend=false", "-input=false", "-no-color")
        self.run_tf("validate", "-no-color")
        self.run_tf("plan", "-out=fixture.plan", "-input=false", "-no-color")
        plan = json.loads(self.run_tf("show", "-json", "fixture.plan"))
        self.assertEqual(plan.get("resource_changes", []), [])
        self.assertFalse(any(secret in json.dumps(plan) for secret in self.secrets))
        self.run_tf("apply", "-input=false", "-no-color", "fixture.plan")
        agents = self.outputs()["agents"]
        self.assertEqual(set(agents), set(PROFILES))
        for name, assistant in agents.items():
            with self.subTest(profile=name):
                self.assertIsNone(assistant["agent"]["id"])
                self.assertFalse(assistant["capabilities"]["remote_lifecycle"])
                body = json.loads(assistant["runtime"]["request_template_json"])
                self.assertEqual(body["model"], "fixture-" + name)
                # The application adds user input without replacing the instruction.
                if assistant["runtime"]["protocol"] == "responses":
                    body["input"] = "Review my change."
                    self.assertEqual(body["instructions"], "Use the declared tools.")
                else:
                    body["messages"].append({"role": "user", "content": "Review my change."})
                    self.assertEqual(body["messages"][0]["content"], "Use the declared tools.")
        self.run_tf("plan", "-input=false", "-detailed-exitcode", "-no-color")
        self.assert_no_resources_or_credentials()

    def test_muse_definition_and_runtime_changes_are_separate(self):
        arguments = {"name": "Muse fixture", "model": "fixture-muse", "instructions": "Review changes."}
        self.configure("modules/muse", **arguments)
        self.run_tf("init", "-backend=false", "-input=false", "-no-color")
        self.run_tf("apply", "-auto-approve", "-input=false", "-no-color")
        before = self.outputs()
        arguments["options"] = {"base_url": "https://gateway.example/meta/v1", "api_key_env": "META_GATEWAY_KEY"}
        self.configure("modules/muse", **arguments)
        self.run_tf("apply", "-auto-approve", "-input=false", "-no-color")
        endpoint_changed = self.outputs()
        self.assertEqual(before["fingerprint"], endpoint_changed["fingerprint"])
        self.assertNotEqual(before["runtime_fingerprint"], endpoint_changed["runtime_fingerprint"])
        self.assertEqual(endpoint_changed["runtime"]["api_key_env"], "META_GATEWAY_KEY")
        arguments["instructions"] = ""
        arguments["model"] = "fixture-muse-next"
        self.configure("modules/muse", **arguments)
        self.run_tf("apply", "-auto-approve", "-input=false", "-no-color")
        cleared = self.outputs()
        self.assertNotEqual(endpoint_changed["fingerprint"], cleared["fingerprint"])
        self.assertNotIn("instructions", json.loads(cleared["runtime"]["request_template_json"]))
        self.assertEqual(cleared["agent"]["model"], "fixture-muse-next")
        self.run_tf("plan", "-input=false", "-detailed-exitcode", "-no-color")
        self.assert_no_resources_or_credentials()
        self.run_tf("destroy", "-auto-approve", "-input=false", "-no-color")
        self.assertEqual(self.outputs(), {})


if __name__ == "__main__":
    unittest.main(verbosity=2)
