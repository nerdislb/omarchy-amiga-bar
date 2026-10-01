"""bin/bar-form.py: the managed [bar] block in the user's shell.toml."""
import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

SCRIPT = Path(__file__).resolve().parent.parent / "bin" / "bar-form.py"


def run(path, action):
    env = dict(os.environ, OMARCHY_USER_SHELL_TOML=str(path))
    p = subprocess.run([sys.executable, str(SCRIPT), action], env=env, capture_output=True, text=True)
    return p.returncode, json.loads(p.stdout)


class BarForm(unittest.TestCase):
    def setUp(self):
        self.dir = tempfile.TemporaryDirectory()
        self.path = Path(self.dir.name) / "shell.toml"

    def tearDown(self):
        self.dir.cleanup()

    def test_round_trip_keeps_file_and_mode(self):
        original = '[font]\nbase-size = 14\n\n[system-monitor]\ncpu = "accent"\n'
        self.path.write_text(original)
        os.chmod(self.path, 0o600)
        self.assertEqual(run(self.path, "enable"), (0, {"form": "a500", "changed": True}))
        self.assertEqual(run(self.path, "enable")[1]["changed"], False)
        self.assertIn("background-alpha = 0.0", self.path.read_text())
        self.assertEqual(run(self.path, "status")[1]["form"], "a500")
        self.assertEqual(run(self.path, "disable"), (0, {"form": "full", "changed": True}))
        self.assertEqual(self.path.read_text(), original)
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)

    def test_refuses_when_user_sets_bar_keys(self):
        self.path.write_text('[bar]\nbackground = "#000000"\n')
        code, out = run(self.path, "enable")
        self.assertEqual(code, 1)
        self.assertIn("error", out)
        self.assertEqual(self.path.read_text(), '[bar]\nbackground = "#000000"\n')

    def test_missing_file(self):
        self.assertEqual(run(self.path, "status")[1], {"form": "full", "other_bar_keys": []})
        self.assertEqual(run(self.path, "enable")[0], 0)
        self.assertEqual(self.path.stat().st_mode & 0o777, 0o600)


if __name__ == "__main__":
    unittest.main()
