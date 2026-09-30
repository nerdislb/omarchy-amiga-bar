#!/usr/bin/env python3
"""Amiga desktop font profile for the Amiga Bar: status | enable | restore.

enable puts NerdWorkbench wherever the desktop lets us, on its crisp 16 px
grid: fontconfig routes for the default families (only when they are the
requested first family, so explicit fonts, symbols and emoji stay intact),
pixel rendering for NerdWorkbench, the Omarchy shell type scale (16/32 px),
GTK interface fonts, Ghostty/Kitty and Zen/Firefox chrome.

Every change is a marked block or a recorded previous value; restore removes
exactly those and uninstalls the fonts. Each run keeps a backup of the files
it touched in ~/.local/state/amiga-bar/font-profile-* (newest five kept).
"""
import argparse
import ast
import fcntl
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from xml.sax.saxutils import escape
import xml.etree.ElementTree as ET

HOME = Path.home()
START = '<!-- BEGIN Amiga Bar system font -->'
END = '<!-- END Amiga Bar system font -->'
BLOCK = re.compile(r'\n?' + re.escape(START) + r'.*?' + re.escape(END) + r'\n?', re.S)
EMPTY = '<?xml version="1.0"?>\n<!DOCTYPE fontconfig SYSTEM "fonts.dtd">\n<fontconfig>\n</fontconfig>\n'
FAMILY = 'NerdWorkbench Mono'
ICONS = 'NerdWorkbench Icons'
FONT_FILES = ['NerdWorkbenchMono-Regular.ttf', 'NerdWorkbenchMono-Bold.ttf', 'NerdWorkbenchIcons.ttf']
STALE_FONTS = ['NerdWorkbenchUI-Regular.ttf', 'NerdWorkbenchUI-Bold.ttf', 'Topaz_a500_v1.0.ttf', 'TopazPlus_a500_v1.0.ttf']
# '#'-comment files (shell.toml, Ghostty, Kitty) and CSS use text markers.
HASH_START, HASH_END = '# BEGIN Amiga Bar font profile', '# END Amiga Bar font profile'
CSS_START, CSS_END = '/* BEGIN Amiga Bar font profile */', '/* END Amiga Bar font profile */'
GENERICS = ['monospace', 'sans-serif', 'serif', 'system-ui', 'ui-monospace', 'ui-sans-serif',
            'Monospace', 'Sans', 'Sans Serif', 'Serif']
ICON_FAMILIES = ['Symbols Nerd Font', 'Symbols Nerd Font Mono', 'omarchy']
GSETTINGS = ['font-name', 'document-font-name', 'monospace-font-name']
SHELL_TOKENS = {'caption': 16, 'body-small': 16, 'body': 16, 'subtitle': 16, 'title': 16,
                'heading': 16, 'display': 32, 'display-large': 32,
                'icon-small': 16, 'icon': 16, 'icon-large': 16}
BACKUPS_KEPT = 5


def strip_block(text, start, end):
    if text.count(start) != text.count(end):
        raise ValueError(f'Incomplete "{start}" block; file left unchanged')
    return re.sub(r'\n*' + re.escape(start) + r'.*?' + re.escape(end) + r'\n?', '\n', text, flags=re.S)


def add_block(text, start, end, body):
    clean = strip_block(text, start, end).rstrip('\n')
    return (clean + '\n\n' if clean else '') + start + '\n' + body.rstrip('\n') + '\n' + end + '\n'


def remove_block(text, start, end):
    clean = strip_block(text, start, end).rstrip('\n')
    return clean + '\n' if clean else ''


# ------------------------------------------------------------- fontconfig
def fc_route(family, target):
    return ('  <match target="pattern"><test name="family" qual="first"><string>' + escape(family)
            + '</string></test><edit name="family" mode="prepend" binding="strong">'
            + ''.join('<string>' + t + '</string>' for t in target) + '</edit></match>')


def pixel_rules(family, extra=''):
    return ('  <match target="font"><test name="family" qual="any"><string>' + family + '</string></test>'
            '<edit name="antialias" mode="assign"><bool>false</bool></edit>'
            '<edit name="hinting" mode="assign"><bool>false</bool></edit>'
            '<edit name="autohint" mode="assign"><bool>false</bool></edit>' + extra + '</match>')


def update_xml(text, enabled, families=()):
    """Remove our block; when enabled, route `families` (as first family) to NerdWorkbench."""
    ET.fromstring(text)
    if text.count(START) != text.count(END):
        raise ValueError('Incomplete Amiga font block; existing file preserved')
    clean = BLOCK.sub('\n', text)
    if not enabled:
        return clean
    rules = [pixel_rules(FAMILY, '<edit name="embeddedbitmap" mode="assign"><bool>false</bool></edit>'),
             pixel_rules(ICONS)]
    seen = set()
    for family in list(GENERICS) + list(families):
        if family in seen or family.startswith(('NerdWorkbench', 'Topaz')) or family in ICON_FAMILIES:
            continue
        seen.add(family)
        rules.append(fc_route(family, [FAMILY, ICONS]))
    for family in ICON_FAMILIES:
        rules.append(fc_route(family, [ICONS]))
    block = START + '\n' + '\n'.join(rules) + '\n' + END + '\n'
    at = clean.rfind('</fontconfig>')
    if at < 0:
        raise ValueError('Expected a fontconfig root with a closing tag')
    return clean[:at] + block + clean[at:]


def discover_families(clean, state):
    """Families the desktop resolves to today, with our overlay removed."""
    found = ['JetBrainsMono Nerd Font']
    with tempfile.TemporaryDirectory(prefix='amiga-font-resolve-') as temp:
        config = Path(temp) / 'fontconfig/fonts.conf'
        config.parent.mkdir()
        confd = HOME / '.config/fontconfig/conf.d'
        extra = '<include ignore_missing="yes">' + escape(str(confd)) + '</include>'
        config.write_text(clean.replace('</fontconfig>', extra + '</fontconfig>'))
        env = dict(os.environ, XDG_CONFIG_HOME=temp)
        for generic in ['monospace', 'sans-serif', 'serif']:
            family = subprocess.run(['fc-match', '-f', '%{family[0]}', generic], env=env,
                                    capture_output=True, text=True).stdout.strip()
            if family:
                found.append(family)
    for key in GSETTINGS:
        value = state.get('gsettings', {}).get(key) or gsettings_get(key)
        if value:
            found.append(re.sub(r'\s+\d+(?:\.\d+)?$', '', value))
    for relative, pattern in [
            ('kitty/kitty.conf', r'^\s*font_family\s+(.+)$'),
            ('ghostty/config', r'^\s*font-family\s*=\s*"?([^"\n]+)'),
            ('foot/foot.ini', r'^\s*font\s*=\s*([^:\n]+)'),
            ('alacritty/alacritty.toml', r'family\s*=\s*"([^"]+)"')]:
        file = HOME / '.config' / relative
        if file.exists():
            text = strip_block(file.read_text(), HASH_START, HASH_END)
            found += [f.strip() for f in re.findall(pattern, text, re.M) if f.strip()]
    return [f for f in dict.fromkeys(found) if f]


# ------------------------------------------------------------- GTK
def gsettings_get(key):
    r = subprocess.run(['gsettings', 'get', 'org.gnome.desktop.interface', key], capture_output=True, text=True)
    if r.returncode != 0:
        return None
    try:
        value = ast.literal_eval(r.stdout.strip())
    except (ValueError, SyntaxError):
        return None
    return value if isinstance(value, (str, float, int)) else None


def gsettings_set(key, value):
    subprocess.run(['gsettings', 'set', 'org.gnome.desktop.interface', key, value], check=True)


def gtk_size():
    """Point size that lands on exactly 16 px with Omarchy's text-scaling-factor."""
    factor = gsettings_get('text-scaling-factor')
    try:
        factor = float(factor) if factor else 1.0
    except ValueError:
        factor = 1.0
    return f'{12 / factor:.3f}'.rstrip('0').rstrip('.')


# ------------------------------------------------------------- files
def atomic_write(path, text):
    path = path.resolve()   # write through symlinks (e.g. dotfile repos)
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
        if os.path.exists(temp):
            os.unlink(temp)


def state_dir():
    return HOME / '.local/state/amiga-bar'


def load_state():
    try:
        return json.loads((state_dir() / 'font-profile.json').read_text())
    except (OSError, ValueError):
        return {}


def browser_profiles():
    for base in [HOME / '.config/zen', HOME / '.mozilla/firefox']:
        if base.exists():
            for profile in sorted(base.iterdir()):
                if profile.is_dir() and (profile / 'prefs.js').exists():
                    yield profile


CHROME_CSS = f'''/* Browser chrome only; websites keep their own fonts. */
:root, #navigator-toolbox, #TabsToolbar, #urlbar, #sidebar-box,
menupopup, panel, tooltip, .tab-label, .toolbarbutton-text {{
  font-family: "{FAMILY}", monospace !important;
}}
.tab-label, #urlbar-input, menupopup menuitem, menupopup menu, tooltip {{
  font-size: 16px !important;
}}'''
CONTENT_CSS = f'''@-moz-document url-prefix("http://127.0.0.1:18789/"), url-prefix("http://localhost:18789/") {{
  :root {{ --font-body: "{FAMILY}", monospace !important; --font-display: var(--font-body) !important;
    --font-chat: var(--font-body) !important; --mono: "{FAMILY}", monospace !important; }}
  body, button, input, textarea, select, pre, code, kbd, samp {{ font-family: "{FAMILY}", monospace !important; }}
}}'''


def planned_writes(activate, state):
    """[(path, old_text, new_text)] for every file with a marked block."""
    writes = []
    config = HOME / '.config/fontconfig/fonts.conf'
    text = config.read_text() if config.exists() else EMPTY
    clean = update_xml(text, False)
    new = update_xml(text, True, discover_families(clean, state)) if activate else clean
    if new != text and (config.exists() or activate):
        writes.append((config, text if config.exists() else None, new))
    tokens = '[font]\n' + '\n'.join(f'{k} = {v}' for k, v in SHELL_TOKENS.items())
    hash_files = [
        (HOME / '.config/omarchy/shell.toml', tokens, True),
        (HOME / '.config/ghostty/config', f'font-family = ""\nfont-family = "{FAMILY}"\nfont-size = 12\n'
         '# 2 px between rows: pixel fonts carry no leading\nadjust-cell-height = 2', False),
        (HOME / '.config/kitty/kitty.conf', f'font_family {FAMILY}\nfont_size 12.0', False),
    ]
    for path, body, create in hash_files:
        if not path.exists() and not (activate and create):
            continue
        old = path.read_text() if path.exists() else None
        base = old or ''
        new = add_block(base, HASH_START, HASH_END, body) if activate else remove_block(base, HASH_START, HASH_END)
        if new != base:
            writes.append((path, old, new))
    for profile in browser_profiles():
        for name, css in [('userChrome.css', CHROME_CSS), ('userContent.css', CONTENT_CSS)]:
            path = profile / 'chrome' / name
            old = path.read_text() if path.exists() else None
            base = old or ''
            if not activate and CSS_START not in base:
                continue
            new = add_block(base, CSS_START, CSS_END, css) if activate else remove_block(base, CSS_START, CSS_END)
            if new != base:
                writes.append((path, old, new))
    return writes


def rotate_backups():
    backups = [b for b in state_dir().glob('font-profile-*') if b.is_dir()]
    for old in sorted(backups, key=lambda p: p.stat().st_mtime)[:-BACKUPS_KEPT]:
        shutil.rmtree(old, ignore_errors=True)


# ------------------------------------------------------------- status
def status():
    parts = {}
    conf = HOME / '.config/fontconfig/fonts.conf'
    parts['fontconfig'] = conf.exists() and START in conf.read_text() and FAMILY in conf.read_text()
    for name, path in [('shell', HOME / '.config/omarchy/shell.toml'),
                       ('ghostty', HOME / '.config/ghostty/config'),
                       ('kitty', HOME / '.config/kitty/kitty.conf')]:
        if path.exists():
            parts[name] = HASH_START in path.read_text()
    css = [p / 'chrome' / n for p in browser_profiles() for n in ('userChrome.css', 'userContent.css')]
    if css:
        parts['browser'] = all(p.exists() and CSS_START in p.read_text() for p in css)
    font_dir = HOME / '.local/share/fonts/amiga-bar'
    parts['fonts'] = all((font_dir / f).exists() for f in FONT_FILES)
    gtk = gsettings_get('font-name')
    if gtk is not None:
        parts['gtk'] = str(gtk).startswith(FAMILY)
    on = [k for k, v in parts.items() if v]
    profile = 'amiga' if len(on) == len(parts) else 'normal' if not on else 'partial'
    return {'enabled': profile == 'amiga', 'profile': profile, 'parts': parts}


# ------------------------------------------------------------- apply
def apply(activate, reload):
    state_dir().mkdir(parents=True, exist_ok=True)
    with (state_dir() / 'font-profile.lock').open('w') as lock:
        fcntl.flock(lock, fcntl.LOCK_EX)
        state = load_state()
        writes = planned_writes(activate, state)
        font_dir = HOME / '.local/share/fonts/amiga-bar'
        if activate:
            source = Path(__file__).resolve().parent.parent / 'assets/fonts/nerdworkbench'
            font_dir.mkdir(parents=True, exist_ok=True)
            for name in FONT_FILES:
                install_font(source / name, font_dir / name)
            for name in STALE_FONTS:
                (font_dir / name).unlink(missing_ok=True)   # unlinking is safe for mmap readers
            subprocess.run(['fc-cache', str(font_dir)], check=True, stdout=subprocess.DEVNULL)
        backup = Path(tempfile.mkdtemp(prefix='font-profile-', dir=state_dir()))
        done = []
        try:
            for i, (path, old, new) in enumerate(writes):
                atomic_write(backup / f'{i}.before', old or '')
                if new:
                    atomic_write(path, new)
                else:
                    path.resolve().unlink(missing_ok=True)   # held only our block
                done.append((path, old))
            atomic_write(backup / 'paths.json', json.dumps([str(p) for p, _, _ in writes], indent=2) + '\n')
            # GTK: remember the user's values; only undo values that are still ours.
            recorded = dict(state.get('gsettings', {}))
            pt = gtk_size()
            for key in GSETTINGS:
                current = gsettings_get(key)
                if current is None:
                    continue
                if activate:
                    if not str(current).startswith(FAMILY):
                        recorded[key] = current
                    gsettings_set(key, f'{FAMILY} {pt}')
                elif key in recorded:
                    if str(current).startswith(FAMILY):
                        gsettings_set(key, recorded[key])
                    recorded.pop(key)
            state = {'gsettings': recorded} if activate else {}
            atomic_write(state_dir() / 'font-profile.json', json.dumps(state, indent=2) + '\n')
        except Exception:
            for path, old in reversed(done):
                if old is None:
                    path.unlink(missing_ok=True)
                else:
                    atomic_write(path, old)
            raise
        if not activate and font_dir.exists():
            for name in FONT_FILES + STALE_FONTS:
                (font_dir / name).unlink(missing_ok=True)
            try:
                font_dir.rmdir()
            except OSError:
                pass   # holds files that are not ours
            subprocess.run(['fc-cache', str(font_dir.parent)], stdout=subprocess.DEVNULL)
        rotate_backups()
    if reload:
        reload_apps()


def reload_apps():
    # Ghostty reloads its config on SIGUSR2 (as omarchy-font-set does).
    subprocess.run(['pkill', '-SIGUSR2', '-x', 'ghostty'], stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)
    subprocess.Popen(['omarchy', 'restart', 'shell'], start_new_session=True,
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def main():
    parser = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    parser.add_argument('action', choices=['status', 'enable', 'restore', 'reload'])
    parser.add_argument('--no-reload', action='store_true',
                        help='Do not reload Ghostty or restart the shell (the caller does it).')
    args = parser.parse_args()
    if args.action == 'status':
        print(json.dumps(status()))
        return
    if args.action == 'reload':
        reload_apps()
        return
    activate = args.action == 'enable'
    apply(activate, not args.no_reload)
    result = status()
    result['message'] = ('Amiga font profile on. Restart Zen and reopen other apps to see it everywhere.'
                         if activate else 'Font profile removed; your previous fonts are back. Restart Zen and reopen other apps.')
    print(json.dumps(result), flush=True)


if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(json.dumps({'error': str(e)}))
        raise SystemExit(1)
