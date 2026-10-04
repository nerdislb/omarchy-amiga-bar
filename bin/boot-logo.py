#!/usr/bin/env python3
"""Boot screen logo (Plymouth) for the Amiga Bar's logos: set | restore | status | render.

The boot screen asks for the disk password before the desktop starts; Omarchy
draws it from /usr/share/plymouth/themes/omarchy (logo.png on a background and
text colour, see omarchy-plymouth-set). This puts the bar's own marks there:

  nerdibeard  the seal as a finished stamp impression, a fifth smaller than the
              230 px logo box, set a touch crooked like a hand stamp
  arch        the official Arch Linux mark, unaltered, 230 px

from the logo design round of 04.10. (assets/boot/*.alpha: 240 x 240 alpha
masks rendered by the design's own code), in the theme's foreground on its
background.

set LOGO [--theme NAME]      compose and install with omarchy-plymouth-set
                             (asks for your sudo password, rebuilds the initramfs)
restore [--theme NAME]       the theme's own unlock.png (omarchy-plymouth-set-by-theme)
restore --default            Omarchy's default logo
status                       what the boot screen shows now
render LOGO OUT.png [--theme NAME]   compose only
"""
import argparse
import os
from pathlib import Path
import re
import struct
import subprocess
import sys
import zlib

HERE = Path(__file__).resolve().parent
ASSETS = HERE.parent / 'assets/boot'
LOGOS = ('nerdibeard', 'arch')
INSTALLED = Path('/usr/share/plymouth/themes/omarchy/logo.png')
STATE = Path.home() / '.local/state/amiga-bar/boot-logo'
CURRENT = Path.home() / '.local/state/omarchy/current/theme'


def read_mask(logo):
    data = (ASSETS / f'{logo}.alpha').read_bytes()
    if data[:4] != b'AMBA':
        raise ValueError(f'{logo}.alpha: not an alpha mask')
    w, h = struct.unpack('>HH', data[4:8])
    alpha = zlib.decompress(data[8:])
    if len(alpha) != w * h:
        raise ValueError(f'{logo}.alpha: {len(alpha)} bytes for {w} x {h}')
    return w, h, alpha


def hex_rgb(value):
    value = value.strip().lstrip('#')
    if not re.fullmatch(r'[0-9A-Fa-f]{6}', value):
        raise ValueError(f'not a #RRGGBB colour: {value}')
    return tuple(int(value[i:i + 2], 16) for i in (0, 2, 4))


def png(w, h, rgba):
    """An RGBA PNG (8 bit, no interlace, filter 0 on every row)."""
    def chunk(kind, body):
        return struct.pack('>I', len(body)) + kind + body + struct.pack('>I', zlib.crc32(kind + body) & 0xffffffff)
    rows = b''.join(b'\x00' + rgba[y * w * 4:(y + 1) * w * 4] for y in range(h))
    return (b'\x89PNG\r\n\x1a\n' + chunk(b'IHDR', struct.pack('>IIBBBBB', w, h, 8, 6, 0, 0, 0))
            + chunk(b'IDAT', zlib.compress(rows, 9)) + chunk(b'IEND', b''))


def compose(logo, ink):
    """The logo's mask in one colour: (width, height, PNG bytes)."""
    w, h, alpha = read_mask(logo)
    r, g, b = hex_rgb(ink)
    rgba = bytearray(w * h * 4)
    rgba[0::4] = bytes([r]) * (w * h)
    rgba[1::4] = bytes([g]) * (w * h)
    rgba[2::4] = bytes([b]) * (w * h)
    rgba[3::4] = alpha
    return w, h, png(w, h, bytes(rgba))


def theme_dir(name):
    if not name:
        return CURRENT
    out = subprocess.run(['omarchy-theme-dir', name], capture_output=True, text=True)
    path = Path(out.stdout.strip())
    if out.returncode or not path.is_dir():
        raise SystemExit(f'boot-logo: no theme named {name}')
    return path


def theme_colors(path):
    """background and foreground of a theme's colors.toml (as omarchy-plymouth-set-by-theme reads them)."""
    found = dict(re.findall(r'^\s*(background|foreground)\s*=\s*"?(#[0-9A-Fa-f]{6})', (path / 'colors.toml').read_text(), re.M))
    if 'background' not in found or 'foreground' not in found:
        raise SystemExit(f'boot-logo: {path}/colors.toml has no background/foreground')
    return found['background'], found['foreground']


def theme_label(name):
    if name:
        return name
    out = subprocess.run(['omarchy-theme-current'], capture_output=True, text=True)
    return re.sub(r'[^a-z0-9]+', '-', out.stdout.strip().lower()).strip('-') or 'current'


def cmd_render(args):
    bg, fg = theme_colors(theme_dir(args.theme))
    _, _, data = compose(args.logo, fg)
    Path(args.out).write_bytes(data)
    print(f'{args.out}: {args.logo} in {fg} (background {bg})')


def cmd_set(args):
    path = theme_dir(args.theme)
    bg, fg = theme_colors(path)
    _, _, data = compose(args.logo, fg)
    STATE.mkdir(parents=True, exist_ok=True)
    out = STATE / f'{args.logo}-{theme_label(args.theme)}.png'
    tmp = out.with_suffix('.tmp')
    tmp.write_bytes(data)
    os.replace(tmp, out)
    print(f'Boot screen: {args.logo} in {fg} on {bg} ({out})')
    print('omarchy-plymouth-set asks for your sudo password and rebuilds the initramfs.')
    sys.stdout.flush()
    os.execvp('omarchy-plymouth-set', ['omarchy-plymouth-set', bg, fg, str(out)])


def cmd_restore(args):
    if args.default:
        os.execvp('omarchy-plymouth-set', ['omarchy-plymouth-set', '--refresh-default'])
    name = args.theme or theme_label(None)
    os.execvp('omarchy-plymouth-set-by-theme', ['omarchy-plymouth-set-by-theme', name])


def status():
    try:
        installed = INSTALLED.read_bytes()
    except OSError:
        return 'no Omarchy boot screen installed'
    for f in sorted(STATE.glob('*.png')) if STATE.is_dir() else []:
        if f.read_bytes() == installed:
            logo, _, theme = f.stem.partition('-')
            return f'{logo} ({theme} colours)'
    out = subprocess.run(['omarchy-plymouth-current'], capture_output=True, text=True)
    return (out.stdout.strip() or 'another logo') + ' (Omarchy)'


def main():
    p = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    sub = p.add_subparsers(dest='cmd', required=True)
    s = sub.add_parser('set'); s.add_argument('logo', choices=LOGOS); s.add_argument('--theme')
    r = sub.add_parser('render'); r.add_argument('logo', choices=LOGOS); r.add_argument('out'); r.add_argument('--theme')
    rs = sub.add_parser('restore'); g = rs.add_mutually_exclusive_group(); g.add_argument('--theme'); g.add_argument('--default', action='store_true')
    sub.add_parser('status')
    args = p.parse_args()
    if args.cmd == 'set':
        cmd_set(args)
    elif args.cmd == 'render':
        cmd_render(args)
    elif args.cmd == 'restore':
        cmd_restore(args)
    else:
        print(status())


if __name__ == '__main__':
    main()
