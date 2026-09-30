"""fastfetch logo helper: enable → enable → restore in a fake HOME is byte-identical."""
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest

SCRIPT = Path(__file__).resolve().parents[1] / 'bin/fastfetch-logo.py'
CONFIG = '''{
  "$schema": "https://github.com/fastfetch-cli/fastfetch/raw/dev/doc/json_schema.json",
  "logo": {
    "type": "builtin",
    "source": "arch_small",
    "padding": {
      "top": 2,
      "right": 3,
      "left": 2
    }
  },
  "display": {
    "disableLinewrap": true
  },
  "modules": ["break", {"type": "custom", "format": "\\u001b[90m{ brace in a string }"}]
}
'''


class FastfetchLogoTests(unittest.TestCase):
    def run_logo(self, home, action):
        out = subprocess.run([sys.executable, str(SCRIPT), action], env=dict(os.environ, HOME=str(home)),
                             capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, out.stderr)
        return json.loads(out.stdout.strip().splitlines()[-1])

    def test_round_trip(self):
        with tempfile.TemporaryDirectory() as d:
            home = Path(d)
            cfg = home / '.config/fastfetch/config.jsonc'
            cfg.parent.mkdir(parents=True)
            cfg.write_text(CONFIG)
            self.assertTrue(self.run_logo(home, 'enable')['enabled'])
            first = cfg.read_text()
            self.run_logo(home, 'enable')
            self.assertEqual(cfg.read_text(), first)
            parsed = json.loads(first)
            self.assertEqual(parsed['logo']['type'], 'file-raw')
            self.assertEqual(parsed['logo']['padding'], {'top': 2, 'right': 3, 'left': 2})
            self.assertEqual(parsed['modules'][1]['format'], '\x1b[90m{ brace in a string }')
            self.assertTrue((home / '.config/omarchy/hooks/theme-set.d/amiga-fastfetch-logo').exists())
            self.assertIn('█', (home / '.config/fastfetch/amiga-logo.ansi').read_text())
            self.assertFalse(self.run_logo(home, 'restore')['enabled'])
            self.assertEqual(cfg.read_text(), CONFIG)
            self.assertFalse((home / '.config/fastfetch/amiga-logo.ansi').exists())
            self.assertFalse((home / '.config/omarchy/hooks/theme-set.d/amiga-fastfetch-logo').exists())


if __name__ == '__main__':
    unittest.main()
