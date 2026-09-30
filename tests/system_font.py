"""Font profile tests in isolation (fake HOME, private fontconfig); never touch the user's desktop."""
import importlib.util
import json
import os
from pathlib import Path
import subprocess
import sys
import tempfile
import unittest
sys.dont_write_bytecode = True

ROOT = Path(__file__).resolve().parents[1]
SCRIPT = ROOT / 'bin/system-font.py'
spec = importlib.util.spec_from_file_location('system_font', SCRIPT)
font = importlib.util.module_from_spec(spec)
spec.loader.exec_module(font)


class UnitTests(unittest.TestCase):
    def test_preserve_and_restore(self):
        original = '<fontconfig>\n<!-- personal rule -->\n<alias><family>Custom</family><prefer><family>DejaVu Sans</family></prefer></alias>\n</fontconfig>\n'
        enabled = font.update_xml(original, True, ['Inconsolata Nerd Font Mono'])
        self.assertIn('<!-- personal rule -->', enabled)
        self.assertNotIn('qual="any"><string>Inconsolata', enabled)
        self.assertIn('qual="first"><string>Inconsolata Nerd Font Mono', enabled)
        self.assertEqual(font.update_xml(enabled, True).count(font.START), 1)
        self.assertEqual(font.update_xml(enabled, False).strip(), original.strip())

    def test_marked_blocks(self):
        user = '[font]\nbase-size = 14\n\n[system-monitor]\ncpu = "accent"\n'
        on = font.add_block(user, font.HASH_START, font.HASH_END, '[font]\nbody = 16')
        self.assertEqual(font.add_block(on, font.HASH_START, font.HASH_END, '[font]\nbody = 16'), on)
        self.assertEqual(font.remove_block(on, font.HASH_START, font.HASH_END), user)
        self.assertEqual(font.remove_block(font.add_block('', font.HASH_START, font.HASH_END, 'x'),
                                           font.HASH_START, font.HASH_END), '')
        with self.assertRaises(ValueError):
            font.strip_block(font.HASH_START + '\nx\n', font.HASH_START, font.HASH_END)

    def test_atomic_font_replacement_keeps_old_reader(self):
        with tempfile.TemporaryDirectory() as d:
            source, target = Path(d) / 'new.ttf', Path(d) / 'installed.ttf'
            source.write_bytes(b'new-font'); target.write_bytes(b'old-font')
            with target.open('rb') as reader:
                font.install_font(source, target)
                self.assertEqual(reader.read(), b'old-font')
                self.assertEqual(target.read_bytes(), b'new-font')
            inode = target.stat().st_ino
            font.install_font(source, target)
            self.assertEqual(target.stat().st_ino, inode)


class ResolutionTests(unittest.TestCase):
    """Real fc-match against a private config: only first-family requests move."""

    def test_routes_are_scoped(self):
        with tempfile.TemporaryDirectory() as d:
            cfg = Path(d) / 'cfg/fontconfig/fonts.conf'
            cfg.parent.mkdir(parents=True)
            base = ('<fontconfig>\n<dir>' + str(ROOT / 'assets/fonts/nerdworkbench') + '</dir>\n'
                    '<cachedir>' + d + '/cache</cachedir>\n</fontconfig>\n')
            cfg.write_text(base)
            env = dict(os.environ, XDG_CONFIG_HOME=str(Path(d) / 'cfg'), XDG_CACHE_HOME=d + '/cache')

            def match(name, fmt='%{family[0]}'):
                return subprocess.check_output(['fc-match', '-f', fmt, name], env=env, text=True)
            # Omarchy's 50-omarchy.conf rewrites the generics before user rules
            # run; the profile routes what they resolve to (as enable does).
            original = match('monospace')
            resolved = [match(g) for g in ['monospace', 'sans-serif', 'serif']]
            cfg.write_text(font.update_xml(base, True, resolved))
            for name in ['monospace', 'sans-serif', 'serif'] + resolved:
                self.assertEqual(match(name), font.FAMILY, name)
            self.assertEqual(match('Symbols Nerd Font'), font.ICONS)
            # Explicit families, icon fonts and emoji keep their own fonts.
            for name in ['Arial', 'Helvetica', 'Inter', 'DejaVu Sans', 'Font Awesome 6 Free',
                         'Noto Color Emoji', 'Some Unknown Family']:
                self.assertNotEqual(match(name), font.FAMILY, name)
            self.assertEqual(match(font.FAMILY + ':style=Regular', '%{antialias}'), 'False')
            cfg.write_text(font.update_xml(cfg.read_text(), False))
            self.assertEqual(match('monospace'), original)


class EndToEndTests(unittest.TestCase):
    """enable / enable / restore with a fake HOME and stubbed desktop commands."""

    def setUp(self):
        self.tmp = tempfile.TemporaryDirectory()
        home = self.home = Path(self.tmp.name) / 'home'
        stub = Path(self.tmp.name) / 'bin'
        stub.mkdir()
        store = self.store = Path(self.tmp.name) / 'gsettings.json'
        store.write_text(json.dumps({'font-name': 'Adwaita Sans 11', 'document-font-name': 'Adwaita Sans 12',
                                     'monospace-font-name': 'Adwaita Mono 11', 'text-scaling-factor': 1.1818}))
        (stub / 'gsettings').write_text(f'''#!/usr/bin/env python3
import json, sys
store = {str(store)!r}
data = json.load(open(store))
if sys.argv[1] == 'get':
    v = data[sys.argv[3]]
    print(repr(v) if isinstance(v, str) else v)
else:
    data[sys.argv[3]] = sys.argv[4]
    json.dump(data, open(store, 'w'))
''')
        for name in ['fc-cache', 'pkill', 'omarchy']:
            (stub / name).write_text('#!/bin/sh\necho "$0 $*" >> ' + self.tmp.name + '/calls.log\n')
        for f in stub.iterdir():
            f.chmod(0o755)
        files = {
            '.config/fontconfig/fonts.conf': font.EMPTY,
            '.config/omarchy/shell.toml': '[font]\nbase-size = 14\n\n[system-monitor]\ncpu = "accent"\n',
            '.config/ghostty/config': 'font-family = "Inconsolata Nerd Font Mono"\nfont-size = 11\n',
            '.config/kitty/kitty.conf': 'font_family Inconsolata Nerd Font Mono\nfont_size 11.0\n',
            '.config/zen/p.default/prefs.js': '// prefs\n',
            '.config/zen/p.default/chrome/userChrome.css': '/* mine */\n#nav-bar { color: red; }\n',
        }
        for rel, text in files.items():
            (home / rel).parent.mkdir(parents=True, exist_ok=True)
            (home / rel).write_text(text)
        self.files = files
        self.env = dict(os.environ, HOME=str(home), PATH=str(stub) + ':' + os.environ['PATH'],
                        XDG_CACHE_HOME=str(home / '.cache'))

    def tearDown(self):
        self.tmp.cleanup()

    def run_font(self, action):
        out = subprocess.run([sys.executable, str(SCRIPT), action, '--no-reload'], env=self.env,
                             capture_output=True, text=True)
        self.assertEqual(out.returncode, 0, out.stdout + out.stderr)
        return json.loads(out.stdout)

    def test_enable_twice_then_restore(self):
        home = self.home
        first = self.run_font('enable')
        self.assertEqual(first['profile'], 'amiga', first)
        snapshot = {rel: (home / rel).read_text() for rel in self.files}
        self.assertEqual(self.run_font('enable')['profile'], 'amiga')
        for rel, text in snapshot.items():
            self.assertEqual((home / rel).read_text(), text, rel)   # idempotent
        conf = (home / '.config/fontconfig/fonts.conf').read_text()
        self.assertIn('qual="first"><string>Inconsolata Nerd Font Mono', conf)
        self.assertIn('body = 16', (home / '.config/omarchy/shell.toml').read_text())
        self.assertIn('font-size = 12', (home / '.config/ghostty/config').read_text())
        self.assertTrue((home / '.config/zen/p.default/chrome/userContent.css').exists())
        gs = json.loads(self.store.read_text())
        self.assertEqual(gs['font-name'], 'NerdWorkbench Mono 10.154')
        for name in font.FONT_FILES:
            self.assertTrue((home / '.local/share/fonts/amiga-bar' / name).exists())

        done = self.run_font('restore')
        self.assertEqual(done['profile'], 'normal', done)
        for rel, text in self.files.items():
            self.assertEqual((home / rel).read_text(), text, rel)
        self.assertFalse((home / '.config/zen/p.default/chrome/userContent.css').exists())
        self.assertFalse((home / '.local/share/fonts/amiga-bar').exists())
        gs = json.loads(self.store.read_text())
        self.assertEqual(gs['font-name'], 'Adwaita Sans 11')
        self.assertEqual(gs['monospace-font-name'], 'Adwaita Mono 11')

    def test_restore_keeps_user_font_changes(self):
        self.run_font('enable')
        gs = json.loads(self.store.read_text())
        gs['font-name'] = 'Cantarell 11'           # changed by the user meanwhile
        self.store.write_text(json.dumps(gs))
        self.run_font('restore')
        self.assertEqual(json.loads(self.store.read_text())['font-name'], 'Cantarell 11')

    def test_backups_rotate(self):
        for _ in range(4):
            self.run_font('enable')
            self.run_font('restore')
        backups = list((self.home / '.local/state/amiga-bar').glob('font-profile-*'))
        self.assertLessEqual(len([b for b in backups if b.is_dir()]), font.BACKUPS_KEPT)


if __name__ == '__main__':
    unittest.main()
