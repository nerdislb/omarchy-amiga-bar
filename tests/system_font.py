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

    def test_browser_css_scoped_and_reversible(self):
        original = '/* user rule */\nbody {color: red;}\n'
        active = font.css_profile(original, True, content=True)
        self.assertIn('http://127.0.0.1:18789/', active)
        self.assertNotIn('domain(', active)
        self.assertEqual(font.css_profile(active, False).strip(), original.strip())
        later = active + '/* later edit */\n'
        restored = font.css_profile(later,False)
        self.assertIn('/* later edit */', restored)
        self.assertNotIn('NerdWorkbench', restored)
        self.assertEqual(font.css_profile(active,True,content=True).count(font.CSS_START),1)

    def test_atomic_font_replacement_keeps_old_reader(self):
        with tempfile.TemporaryDirectory() as d:
            source, target = Path(d)/'new.ttf', Path(d)/'installed.ttf'
            source.write_bytes(b'new-font'); target.write_bytes(b'old-font')
            with target.open('rb') as reader:
                font.install_font(source, target)
                self.assertEqual(reader.read(), b'old-font')
                self.assertEqual(target.read_bytes(), b'new-font')
            inode = target.stat().st_ino
            font.install_font(source,target)
            self.assertEqual(target.stat().st_ino,inode)

    def test_actual_resolution(self):
        with tempfile.TemporaryDirectory() as d:
            path = Path(d) / 'fonts.conf'
            base = '<fontconfig>\n<include>/etc/fonts/fonts.conf</include>\n<dir>' + str(ROOT / 'assets/fonts/nerdworkbench') + '</dir>\n</fontconfig>\n'
            path.write_text(base)
            env = dict(os.environ, FONTCONFIG_FILE=str(path), XDG_CONFIG_HOME=str(Path(d)/"clean-config"))
            def match(name):
                return subprocess.check_output(['fc-match', '-f', '%{family[0]}', name], env=env, text=True)
            original = match('monospace')
            path.write_text(font.update_xml(base, True, [original]))
            for name in ['monospace', original]:
                self.assertEqual(match(name), font.FAMILY)
            for name in ['sans-serif','serif']:
                self.assertEqual(match(name),font.UI_FAMILY)
            path.write_text(font.update_xml(path.read_text(), False))
            self.assertEqual(match('monospace'), original)

if __name__ == '__main__':
    unittest.main()
