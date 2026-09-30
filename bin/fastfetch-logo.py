#!/usr/bin/env python3
"""Amiga logo for fastfetch: status | enable | restore | write.

The rainbow double tick of the Commodore Amiga logo in half-block cells, in
the current Omarchy theme's red/orange/yellow/green/blue (the tick behind is
darker, standing in for the original's outline), with AMIGA underneath.

enable writes ~/.config/fastfetch/amiga-logo.ansi, replaces only the "logo"
object of ~/.config/fastfetch/config.jsonc (the previous one is kept for
restore) and installs a theme-set hook that recolours the logo.
restore puts the previous logo object back and removes the file and hook.
"""
import argparse
import json
import os
from pathlib import Path
import re
import shutil
import sys
import tempfile

HOME = Path.home()
CONFIG = HOME / '.config/fastfetch/config.jsonc'
LOGO = HOME / '.config/fastfetch/amiga-logo.ansi'
STATE = HOME / '.local/state/amiga-bar/fastfetch-logo.json'
HOOK = HOME / '.config/omarchy/hooks/theme-set.d/amiga-fastfetch-logo'
THEME = HOME / '.local/state/omarchy/current/theme/colors.toml'
FALLBACK = {'blue': '#2c6fd6', 'green': '#2a9d4a', 'yellow': '#e0c21c', 'orange': '#e8781e',
            'red': '#e0302a', 'foreground': '#dfe6f0'}

# Geometry of the double tick (measured from the Commodore Amiga logo), in
# pixels of the logo box: each terminal cell is 12 wide and holds two 9 px
# rows (half blocks), matching a 12x18 NerdWorkbench cell.
COLS, HALF_ROWS = 23, 24
CELL_W, HALF_H = 12.0, 9.0
H = HALF_ROWS * HALF_H                  # 216
LONG_LEFT = (59.0, 188.0)               # left edge x at the bottom / top
SHORT_TOP, SHORT_LEFT_BOTTOM = 130.0, 59.0
WIDTH = 40.0                            # horizontal stroke width
REAR = 43.0                             # the second tick sits this far right


def theme_colors():
    colors = dict(FALLBACK)
    try:
        for key, value in re.findall(r'^\s*([A-Za-z_]+)\s*=\s*"(#[0-9A-Fa-f]{6})', THEME.read_text(), re.M):
            if key in colors:
                colors[key] = value
        if 'orange' not in THEME.read_text():
            colors['orange'] = FALLBACK['orange']
    except OSError:
        pass
    return colors


def rgb(hexc, factor=1.0):
    return tuple(int(int(hexc[i:i + 2], 16) * factor) for i in (1, 3, 5))


def part(x, y, dx):
    """'long', 'short' or None for a point of the tick shifted by dx."""
    x -= dx
    left = LONG_LEFT[0] + (H - y) / H * (LONG_LEFT[1] - LONG_LEFT[0])
    if left <= x <= left + WIDTH:
        return 'long'
    if y >= SHORT_TOP:
        sl = (y - SHORT_TOP) / (H - SHORT_TOP) * SHORT_LEFT_BOTTOM
        if sl <= x <= sl + WIDTH:
            return 'short'
    return None


def band(kind, y):
    h = 1 - y / H                     # 0 at the bottom, 1 at the top
    if kind == 'short':
        return 'blue' if h > 0.16 else 'green'
    return 'green' if h < 0.22 else 'yellow' if h < 0.47 else 'orange' if h < 0.72 else 'red'


def pixel(c, hr):
    """Colour key of one half cell: front tick wins over the rear one."""
    votes = {}
    for sx in range(4):
        for sy in range(4):
            x = (c + (sx + 0.5) / 4) * CELL_W
            y = (hr + (sy + 0.5) / 4) * HALF_H
            for dx, rear in ((0.0, False), (REAR, True)):
                kind = part(x, y, dx)
                if kind:
                    key = (band(kind, y), rear)
                    votes[key] = votes.get(key, 0) + 1
                    break
    if not votes:
        return None
    key, n = max(votes.items(), key=lambda kv: kv[1])
    return key if sum(votes.values()) >= 8 else None


def render(colors):
    def sgr(key, ground):
        name, rear = key
        r, g, b = rgb(colors[name], 0.58 if rear else 1.0)
        return f'\x1b[{38 if ground == "fg" else 48};2;{r};{g};{b}m'
    lines = []
    for row in range(HALF_ROWS // 2):
        out = []
        for c in range(COLS):
            top, bottom = pixel(c, row * 2), pixel(c, row * 2 + 1)
            if top is None and bottom is None:
                out.append(' ')
            elif top == bottom:
                out.append(sgr(top, 'fg') + '█\x1b[0m')
            elif bottom is None:
                out.append(sgr(top, 'fg') + '▀\x1b[0m')
            elif top is None:
                out.append(sgr(bottom, 'fg') + '▄\x1b[0m')
            else:
                out.append(sgr(top, 'fg') + sgr(bottom, 'bg') + '▀\x1b[0m')
        lines.append(''.join(out).rstrip())
    fr, fg, fb = rgb(colors['foreground'])
    word = 'A M I G A'
    lines.append('')
    lines.append(' ' * ((COLS - len(word)) // 2) + f'\x1b[1;38;2;{fr};{fg};{fb}m{word}\x1b[0m')
    return '\n'.join(lines) + '\n', COLS, len(lines)


def atomic_write(path, text, mode=0o644):
    path = path.resolve() if path.exists() else path
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, tmp = tempfile.mkstemp(dir=path.parent, prefix='.amiga-')
    try:
        with os.fdopen(fd, 'w') as f:
            f.write(text)
        os.chmod(tmp, path.stat().st_mode & 0o777 if path.exists() else mode)
        os.replace(tmp, path)
    finally:
        if os.path.exists(tmp):
            os.unlink(tmp)


def logo_span(text):
    """(start, end) of the value of the top-level "logo" key in JSONC text."""
    m = re.search(r'"logo"\s*:\s*', text)
    if not m:
        return None
    i, depth, in_str, esc = m.end(), 0, False, False
    if text[i] != '{':
        end = re.search(r'[,\n}]', text[i:]).start() + i
        return m.end(), end
    for j in range(i, len(text)):
        ch = text[j]
        if in_str:
            esc = ch == '\\' and not esc
            if ch == '"' and not esc:
                in_str = False
            continue
        if ch == '"':
            in_str = True
        elif ch == '{':
            depth += 1
        elif ch == '}':
            depth -= 1
            if depth == 0:
                return i, j + 1
    raise ValueError('unbalanced logo object in fastfetch config')


def write_logo():
    text, width, height = render(theme_colors())
    atomic_write(LOGO, text)
    return width, height


HOOK_BODY = '''#!/bin/bash
# Amiga Bar: recolour the fastfetch Amiga logo for the new theme.
exec python3 {script} write >/dev/null 2>&1
'''


def enable():
    width, height = write_logo()
    text = CONFIG.read_text()
    span = logo_span(text)
    state = json.loads(STATE.read_text()) if STATE.exists() else {}
    current = text[span[0]:span[1]] if span else None
    if 'previous' not in state:
        state['previous'] = current            # null: config had no logo key
    padding = {'top': 2, 'right': 3, 'left': 2}
    try:
        padding = json.loads(current).get('padding', padding) if current else padding
    except (ValueError, AttributeError):
        pass
    logo = json.dumps({'type': 'file-raw', 'source': str(LOGO).replace(str(HOME), '~', 1),
                       'width': width, 'height': height, 'padding': padding}, indent=2).replace('\n', '\n  ')
    if span:
        new = text[:span[0]] + logo + text[span[1]:]
    else:
        new = text.replace('{', '{\n  "logo": ' + logo + ',', 1)
    backup = STATE.parent / 'fastfetch-config.before.jsonc'
    if not backup.exists():
        atomic_write(backup, text)
    atomic_write(CONFIG, new)
    atomic_write(STATE, json.dumps(state, indent=2) + '\n')
    atomic_write(HOOK, HOOK_BODY.format(script=Path(__file__).resolve()), 0o755)
    HOOK.chmod(0o755)


def restore():
    if not STATE.exists():
        return
    state = json.loads(STATE.read_text())
    text = CONFIG.read_text()
    span = logo_span(text)
    if span and 'amiga-logo.ansi' in text[span[0]:span[1]]:
        previous = state.get('previous')
        if previous is None:   # there was no logo key: drop ours
            new = re.sub(r'\n\s*"logo"\s*:\s*' + re.escape(text[span[0]:span[1]]) + r'\s*,', '', text, count=1)
        else:
            new = text[:span[0]] + previous + text[span[1]:]
        atomic_write(CONFIG, new)
    HOOK.unlink(missing_ok=True)
    LOGO.unlink(missing_ok=True)
    STATE.unlink(missing_ok=True)


def status():
    text = CONFIG.read_text() if CONFIG.exists() else ''
    span = logo_span(text) if text else None
    active = bool(span and 'amiga-logo.ansi' in text[span[0]:span[1]])
    return {'enabled': active and LOGO.exists(), 'hook': HOOK.exists(), 'config': str(CONFIG)}


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('action', choices=['status', 'enable', 'restore', 'write', 'print'])
    args = ap.parse_args()
    if args.action == 'print':
        sys.stdout.write(render(theme_colors())[0])
        return
    if args.action == 'write':
        if status()['enabled']:
            write_logo()
    elif args.action == 'enable':
        enable()
    elif args.action == 'restore':
        restore()
    print(json.dumps(status()))


if __name__ == '__main__':
    main()
