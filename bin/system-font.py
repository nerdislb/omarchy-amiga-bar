#!/usr/bin/env python3
"""Optional, reversible Topaz fontconfig overlay. Never changes font sizes."""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import subprocess
import tempfile
from xml.sax.saxutils import escape
import xml.etree.ElementTree as ET

START = '<!-- BEGIN Amiga Bar system font -->'
END = '<!-- END Amiga Bar system font -->'
BLOCK = re.compile(r'\n?' + re.escape(START) + r'.*?' + re.escape(END) + r'\n?', re.S)
EMPTY = '<?xml version="1.0"?>\n<!DOCTYPE fontconfig SYSTEM "fonts.dtd">\n<fontconfig>\n</fontconfig>\n'
FAMILY = 'Topaz a500a1000a2000'

def update_xml(text, enabled, families=()):
    ET.fromstring(text)  # Refuse malformed existing configuration.
    clean = BLOCK.sub('\n', text)
    if not enabled:
        return clean
    rules = []
    for family in dict.fromkeys(['monospace', 'sans-serif', 'serif', *families]):
        if family == FAMILY:
            continue
        rules.append('  <match target="pattern"><test name="family" qual="any"><string>'
                     + escape(family) + '</string></test><edit name="family" mode="prepend_first" binding="strong"><string>'
                     + FAMILY + '</string></edit></match>')
    block = START + '\n' + '\n'.join(rules) + '\n' + END + '\n'
    at = clean.rfind('</fontconfig>')
    if at < 0:
        raise ValueError('Expected a fontconfig root with a closing tag')
    return clean[:at] + block + clean[at:]

def atomic_write(path, text):
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

def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('action', choices=['status', 'enable', 'restore'])
    args = parser.parse_args()
    config = Path.home() / '.config/fontconfig/fonts.conf'
    # Follow a user-managed symlink rather than replacing it.
    config = config.resolve()
    text = config.read_text() if config.exists() else EMPTY
    enabled = START in text
    if args.action == 'status':
        print(json.dumps({'enabled': enabled}))
        return
    if (args.action == 'enable') == enabled:
        print(json.dumps({'enabled': enabled, 'message': 'Already selected'}))
        return
    families = []
    if args.action == 'enable':
        for generic in ['monospace', 'sans-serif', 'serif']:
            family = subprocess.check_output(['fc-match', '-f', '%{family[0]}', generic], text=True).strip()
            if family:
                families.append(family)
    result = update_xml(text, args.action == 'enable', families)
    if args.action == 'enable':
        source = Path(__file__).resolve().parent.parent / 'assets/fonts/Topaz_a500_v1.0.ttf'
        target = Path.home() / '.local/share/fonts/amiga-bar/Topaz_a500_v1.0.ttf'
        target.parent.mkdir(parents=True, exist_ok=True)
        shutil.copyfile(source, target)
        subprocess.run(['fc-cache', str(target.parent)], check=True, stdout=subprocess.DEVNULL)
        backup = Path.home() / '.local/state/amiga-bar/system-font-before.conf'
        atomic_write(backup, text)
    atomic_write(config, result)
    print(json.dumps({'enabled': args.action == 'enable', 'message': 'System font updated. Reopen other apps if needed.'}), flush=True)
    subprocess.Popen(['omarchy', 'restart', 'shell'], start_new_session=True,
                     stdin=subprocess.DEVNULL, stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)

if __name__ == '__main__':
    try:
        main()
    except Exception as e:
        print(json.dumps({'error': str(e)}))
        raise SystemExit(1)
