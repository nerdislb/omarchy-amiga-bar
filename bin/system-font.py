#!/usr/bin/env python3
"""Reversible Amiga desktop typography profile; does not change font sizes."""
import argparse
import ast
import fcntl
import json
import os
from pathlib import Path
import re
import subprocess
import tempfile
from xml.sax.saxutils import escape
import xml.etree.ElementTree as ET

START = '<!-- BEGIN Amiga Bar system font -->'
END = '<!-- END Amiga Bar system font -->'
BLOCK = re.compile(r'\n?' + re.escape(START) + r'.*?' + re.escape(END) + r'\n?', re.S)
EMPTY = '<?xml version="1.0"?>\n<!DOCTYPE fontconfig SYSTEM "fonts.dtd">\n<fontconfig>\n</fontconfig>\n'
FAMILY = 'NerdWorkbench Mono'
UI_FAMILY = 'NerdWorkbench UI'
ICON_FAMILY = 'NerdWorkbench Icons'
CSS_START = '/* BEGIN Amiga Bar font profile */'
CSS_END = '/* END Amiga Bar font profile */'
CSS_BLOCK = re.compile(r'\n?' + re.escape(CSS_START) + r'.*?' + re.escape(CSS_END) + r'\n?', re.S)


def update_xml(text, enabled, families=()):
    ET.fromstring(text)
    if text.count(START) != text.count(END):
        raise ValueError('Incomplete Amiga font block; existing file preserved')
    clean = BLOCK.sub('\n', text)
    if not enabled:
        return clean
    routes = {'monospace': FAMILY, 'sans-serif': UI_FAMILY, 'serif': UI_FAMILY}
    routes.update(families if isinstance(families, dict) else {f: FAMILY for f in families})
    rules = []
    for family, target in routes.items():
        if family.startswith('NerdWorkbench') or family.startswith('Topaz'):
            continue
        rules.append('  <match target="pattern"><test name="family" qual="all" compare="not_eq"><string>NerdWorkbench UI</string></test><test name="family" qual="all" compare="not_eq"><string>NerdWorkbench Mono</string></test><test name="family" qual="any"><string>'
                     + escape(family) + '</string></test><edit name="family" mode="prepend_first" binding="strong"><string>'
                     + target + '</string><string>' + ICON_FAMILY + '</string></edit></match>')
    block = START + '\n' + '\n'.join(rules) + '\n' + END + '\n'
    at = clean.rfind('</fontconfig>')
    if at < 0:
        raise ValueError('Expected a fontconfig root with a closing tag')
    return clean[:at] + block + clean[at:]


def atomic_write(path, text):
    path = path.resolve()
    path.parent.mkdir(parents=True, exist_ok=True)
    mode = path.stat().st_mode & 0o777 if path.exists() else 0o600
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix='.amiga-font-')
    try:
        with os.fdopen(fd, 'w') as f:
            f.write(text)
        os.chmod(tmp, mode)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def install_font(source, target):
    data = source.read_bytes()
    if target.exists() and target.read_bytes() == data:
        return
    # FreeType may mmap this inode. Never truncate/overwrite it in place.
    fd, temp = tempfile.mkstemp(dir=target.parent, prefix='.font-')
    try:
        with os.fdopen(fd, 'wb') as file:
            file.write(data)
        os.chmod(temp, 0o644)
        os.replace(temp, target)
    finally:
        if os.path.exists(temp): os.unlink(temp)


def css_profile(text, enabled, content=False):
    if text.count(CSS_START) != text.count(CSS_END):
        raise ValueError('Incomplete Amiga CSS block; existing file preserved')
    clean = CSS_BLOCK.sub('\n', text)
    if not enabled:
        return clean
    if content:
        rules = '''@-moz-document url-prefix("http://127.0.0.1:18789/"), url-prefix("http://localhost:18789/") {
  :root { --font-body: "NerdWorkbench UI", sans-serif !important; --font-display: var(--font-body) !important;
    --font-chat: var(--font-body) !important; --mono: "NerdWorkbench Mono", monospace !important; }
  body, button, input, textarea, select { font-family: "NerdWorkbench UI", sans-serif !important; }
  pre, code, kbd, samp { font-family: "NerdWorkbench Mono", monospace !important; }
}'''
    else:
        rules = '''/* Browser chrome only; does not replace fonts on arbitrary websites. */
:root, #navigator-toolbox, #TabsToolbar, #urlbar, #sidebar-box,
menupopup, panel, tooltip, .tab-label, .toolbarbutton-text {
  font-family: "NerdWorkbench UI", sans-serif !important;
}'''
    return clean.rstrip() + '\n' + CSS_START + '\n' + rules + '\n' + CSS_END + '\n'


def discover_routes(clean):
    routes = {}
    # Resolve defaults with our existing overlay removed, even during migration
    # from classic Topaz. No desktop configuration is temporarily changed.
    with tempfile.TemporaryDirectory(prefix='amiga-font-resolve-') as temp:
        config = Path(temp) / 'fontconfig/fonts.conf'
        config.parent.mkdir()
        confd = Path.home() / '.config/fontconfig/conf.d'
        extra = '<include ignore_missing="yes">' + escape(str(confd)) + '</include>'
        config.write_text(clean.replace('</fontconfig>', extra + '</fontconfig>'))
        env = dict(os.environ, XDG_CONFIG_HOME=temp)
        for generic, target in [('monospace', FAMILY), ('sans-serif', UI_FAMILY), ('serif', UI_FAMILY)]:
            family = subprocess.check_output(['fc-match', '-f', '%{family[0]}', generic], env=env, text=True).strip()
            if family: routes[family] = target
    for key, target in [('font-name', UI_FAMILY), ('document-font-name', UI_FAMILY), ('monospace-font-name', FAMILY)]:
        result = subprocess.run(['gsettings', 'get', 'org.gnome.desktop.interface', key], capture_output=True, text=True)
        if result.returncode == 0:
            try: routes[re.sub(r'\s+\d+(?:\.\d+)?$', '', ast.literal_eval(result.stdout.strip()))] = target
            except (ValueError, SyntaxError): pass
    # Current explicitly configured terminal families (sizes/styles unchanged).
    for relative, pattern in [
        ('kitty/kitty.conf', r'^\s*font_family\s+(.+)$'),
        ('ghostty/config', r'^\s*font-family\s*=\s*"?([^"\n]+)'),
        ('foot/foot.ini', r'^\s*font\s*=\s*([^:\n]+)'),
        ('alacritty/alacritty.toml', r'family\s*=\s*"([^"]+)"')]:
        file = Path.home() / '.config' / relative
        if file.exists():
            for family in re.findall(pattern, file.read_text(), re.M):
                routes[family.strip()] = FAMILY
    return routes


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['status', 'enable', 'restore'])
    parser.add_argument('--no-reload', action='store_true', help='Do not restart the shell (for controlled testing).')
    args = parser.parse_args()
    config = (Path.home() / '.config/fontconfig/fonts.conf').resolve()
    text = config.read_text() if config.exists() else EMPTY
    enabled = START in text
    if args.action == 'status':
        print(json.dumps({'enabled': enabled, 'profile': 'amiga' if UI_FAMILY in text and enabled else 'classic' if enabled else 'normal'}))
        return
    state = Path.home() / '.local/state/amiga-bar'
    state.mkdir(parents=True, exist_ok=True)
    with (state / 'font-profile.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        text = config.read_text() if config.exists() else EMPTY
        activate = args.action == 'enable'
        clean = update_xml(text, False)
        routes = discover_routes(clean) if activate else {}
        writes = [(config, text, update_xml(text, activate, routes))]
        # Profile-specific, marked CSS. Existing rules and all account data stay untouched.
        for browser in ['zen', 'mozilla/firefox']:
            base = Path.home() / '.config' / browser if browser == 'zen' else Path.home() / ('.' + browser)
            if not base.exists(): continue
            for profile in base.iterdir():
                if not profile.is_dir() or not (profile / 'prefs.js').exists(): continue
                for name, content in [('userChrome.css', False), ('userContent.css', True)]:
                    path = profile / 'chrome' / name
                    if not activate and not path.exists(): continue
                    old = path.read_text() if path.exists() else ''
                    if not activate and CSS_START not in old: continue
                    writes.append((path, old, css_profile(old, activate, content)))
        if activate:
            source = Path(__file__).resolve().parent.parent / 'assets/fonts/nerdworkbench'
            target = Path.home() / '.local/share/fonts/amiga-bar'
            target.mkdir(parents=True, exist_ok=True)
            for file in source.glob('*.ttf'): install_font(file, target / file.name)
            subprocess.run(['fc-cache', str(target)], check=True, stdout=subprocess.DEVNULL)
        # Per-operation backup for recovery, and compensating rollback on errors.
        backup = Path(tempfile.mkdtemp(prefix='font-profile-', dir=state))
        done = []
        try:
            for i,(path,old,new) in enumerate(writes):
                existed = path.exists()
                atomic_write(backup / (str(i)+'.before'), old)
                atomic_write(path, new)
                done.append((path,old,existed))
            atomic_write(backup / 'paths.json', json.dumps([str(p) for p,_,_ in writes], indent=2))
        except Exception:
            for path,old,existed in reversed(done):
                if existed: atomic_write(path,old)
                else: path.unlink(missing_ok=True)
            raise
    print(json.dumps({'enabled': activate, 'profile': 'amiga' if activate else 'normal',
        'message': 'Font profile updated. Reopen other apps / restart Zen for browser changes.'}), flush=True)
    if not args.no_reload:
        subprocess.Popen(['omarchy', 'restart', 'shell'], start_new_session=True,
                         stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

if __name__ == '__main__':
    try: main()
    except Exception as e:
        print(json.dumps({'error': str(e)}))
        raise SystemExit(1)
