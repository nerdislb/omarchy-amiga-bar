"""Check fontconfig resolution in isolation; never change the user's fonts."""
import importlib.util
import os
from pathlib import Path
import subprocess
import tempfile
import unittest
import sys
sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
spec = importlib.util.spec_from_file_location('system_font', ROOT / 'bin/system-font.py')
font = importlib.util.module_from_spec(spec)
spec.loader.exec_module(font)

class FontTests(unittest.TestCase):
    def test_preserve_and_restore(self):
        original = '<fontconfig>\n<!-- personal rule -->\n<alias><family>Custom</family><prefer><family>DejaVu Sans</family></prefer></alias>\n</fontconfig>\n'
        enabled = font.update_xml(original, True, ['Inconsolata Nerd Font Mono'])
        self.assertIn('<!-- personal rule -->', enabled)
        self.assertEqual(font.update_xml(enabled, True).count(font.START), 1)
        restored = font.update_xml(enabled, False)
        self.assertEqual(restored.strip(), original.strip())

    def test_actual_resolution(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'fonts.conf'
            base = '<fontconfig>\n<include>/etc/fonts/fonts.conf</include>\n<dir>' + str(ROOT / 'assets/fonts') + '</dir>\n</fontconfig>\n'
            path.write_text(base)
            env = dict(os.environ, FONTCONFIG_FILE=str(path))
            def match(name):
                return subprocess.check_output(['fc-match', '-f', '%{family[0]}', name], env=env, text=True)
            original = match('monospace')
            path.write_text(font.update_xml(base, True, [original]))
            for name in ['monospace', 'sans-serif', 'serif', original]:
                self.assertEqual(match(name), font.FAMILY)
            path.write_text(font.update_xml(path.read_text(), False))
            self.assertEqual(match('monospace'), original)

if __name__ == '__main__':
    unittest.main()
