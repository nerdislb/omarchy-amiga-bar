#!/usr/bin/env python3
"""Build the Chrom (dark) and Platin (light) Omarchy themes into themes/.

The metal family (design round 07.10.2026, recommendation): Chrom is Tusche's
black with a cool steel tint, Platin is Papier turned into cool platinum grey;
red stays the one signal colour. The palette, terminal and launcher files are
derived from Tusche/Papier through one colour function (equal colours stay
equal), the rest is written here: hyprland.lua (a resting chrome gradient that
turns once on focus), bar-material.json (material.metal for the Tusche Bar),
the lock screen symbols in chrome, and the backgrounds.

  tools/build-metal-themes.py [--backgrounds DIR]

DIR holds the generated stills (quecksilber-*.jpg, silber-*.jpg, from
output/metall-2026-10-07/assets/wallpapers); without it the existing
backgrounds in themes/chrom|platin are kept.
"""
import argparse
import json
import re
import shutil
from pathlib import Path

from PIL import Image, ImageChops, ImageFilter

REPO = Path(__file__).resolve().parent.parent
THEMES = REPO / 'themes'
MARK = 'built by tools/build-metal-themes.py (Chrom & Platin, 07.10.2026)\n'


def rgb(h):
    h = h.lstrip('#')
    return tuple(int(h[i:i + 2], 16) for i in (0, 2, 4))


def hexc(c):
    return '#%02x%02x%02x' % tuple(max(0, min(255, round(v))) for v in c)


def luma(c):
    r, g, b = c
    return 0.2126 * r + 0.7152 * g + 0.0722 * b


def is_signal(c):
    r, g, b = c
    return r - max(g, b) > 60


def chrom(h):
    """Tusche → Chrom: neutral greys get a faint steel tint (blue up, red down)."""
    c = rgb(h)
    if is_signal(c):
        return hexc(c)
    y = luma(c)
    if y >= 250:
        return '#ffffff'
    k = min(1.0, y / 60.0) if y < 60 else max(0.0, (250 - y) / 190.0)
    return hexc((y - 3 * k, y - 0.5 * k, y + 5 * k))


def platin(h):
    """Papier → Platin: warm paper greys become cool platinum of the same lightness."""
    c = rgb(h)
    if is_signal(c):
        return '#b02614'
    y = luma(c)
    if y <= 2:
        return '#000000'
    # the paper itself a little lighter and cooler; ink stays as dark
    y2 = y + (6 if y > 150 else 0)
    k = 1.0 if y > 120 else 0.6
    return hexc((y2 - 3 * k, y2, y2 + 4 * k))


HEX = re.compile(r'#[0-9a-fA-F]{6}\b')


def recolor_text(text, fn):
    return HEX.sub(lambda m: fn(m.group(0)), text)


def recolor_rgba(text, fn):
    def sub(m):
        return 'rgba(' + fn('#' + m.group(1))[1:] + m.group(2) + ')'
    return re.sub(r'rgba\(([0-9a-fA-F]{6})([0-9a-fA-F]{2})\)', sub, text)


HYPR = {
    'chrom': '''-- chrom: a resting chrome gradient on the active border that turns once when a window takes
-- focus (borderangle, no loop: a loop would redraw all the time); the window shadow a faint light.
local active_border_color = { colors = { "rgba(f2f3f7ff)", "rgba(8a8c92ff)", "rgba(3b3c41ff)", "rgba(8a8c92ff)", "rgba(f2f3f7ff)" }, angle = 90 }
local inactive_border_color = "rgba(26272aff)"

hl.config({
  general = {
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },

  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },

  decoration = {
    shadow = { enabled = true, range = 22, render_power = 3, offset = { 0, 4 }, color = "rgba(ffffff1c)", color_inactive = "rgba(00000000)" },
  },
})

hl.animation({ leaf = "borderangle", enabled = true, speed = 9, bezier = "easeOutQuint" })
''',
    'platin': '''-- platin: a resting polished-steel gradient on the active border that turns once when a window
-- takes focus (borderangle, no loop); the window shadow a soft dark.
local active_border_color = { colors = { "rgba(1a1b1dff)", "rgba(7a7d82ff)", "rgba(c9ccd0ff)", "rgba(7a7d82ff)", "rgba(1a1b1dff)" }, angle = 90 }
local inactive_border_color = "rgba(b0b3b8ff)"

hl.config({
  general = {
    col = {
      active_border = active_border_color,
      inactive_border = inactive_border_color,
    },
  },

  group = {
    col = {
      border_active = active_border_color,
      border_inactive = inactive_border_color,
    },
  },

  decoration = {
    shadow = { enabled = true, range = 24, render_power = 3, offset = { 0, 4 }, color = "rgba(1112142a)", color_inactive = "rgba(00000000)" },
  },
})

hl.animation({ leaf = "borderangle", enabled = true, speed = 9, bezier = "easeOutQuint" })
''',
}

MATERIAL = {
    'chrom': {
        'family': 'metall',
        'edge': {
            'kind': 'metal',
            'haze': {'color': '#000000', 'height': 22, 'stops': [[0, 0.8], [0.5, 0.32], [1, 0]]},
        },
        'card': {'roll': True, 'glow': {'color': '#ffffff', 'alpha': 0.07, 'blur': 18}},
        'metal': {
            'rim': 1.6, 'ring': 3.4, 'ringSize': 22, 'ringStyle': 2, 'tint': '#f2f3f7', 'disp': 0.8, 'spark': 0.35, 'sharp': 0.78,
            'gain': 1, 'base': 1, 'flow': 0, 'sweepMs': 900, 'track': '#1c1c1f',
            'rings': True, 'meters': True, 'hover': 'tube', 'hoverRadius': 3, 'logo': True,
        },
        'source': {'fill': '#f2f3f7', 'text': '#020203'},
        'tones': {'strong': '#e0e1e5'},
    },
    'platin': {
        'family': 'metall',
        'edge': {
            'kind': 'metal',
            'haze': {'color': '#2a2d32', 'height': 18, 'stops': [[0, 0.32], [0.5, 0.12], [1, 0]]},
        },
        'card': {'roll': True, 'shadow': {'color': '#2a2d32', 'alpha': 0.28, 'dx': 0, 'dy': 4}},
        'metal': {
            'rim': 1.4, 'ring': 3.4, 'ringSize': 22, 'ringStyle': 2, 'tint': '#f7f8fa', 'light': True, 'disp': 0.35, 'spark': 0.15, 'sharp': 0.6,
            'gain': 1, 'base': 1, 'flow': 0, 'sweepMs': 900, 'track': '#b9bcc0',
            'rings': True, 'meters': True, 'hover': 'tube', 'hoverRadius': 3, 'logo': True,
        },
        'source': {'fill': '#111214', 'text': '#e1e3e6'},
        'tones': {'strong': '#141517'},
    },
}

BACKGROUNDS = {
    # the owner's picks first (07.10.: Bild 3 for Chrom, Bild 1 for Platin)
    'chrom': [('quecksilber-2.jpg', '1-quecksilber.jpg'), ('quecksilber-1.jpg', '2-mondsee.jpg'), ('quecksilber-3.jpg', '3-horizont.jpg')],
    'platin': [('silber-2.jpg', '1-silbermeer.jpg')],
}


def chrome_symbols(src, dst, fill, rim_dark, shadow=None):
    """Lock screen symbols: the source's shapes, filled flat, outlined in chrome."""
    im = Image.open(src).convert('RGBA')
    a = im.getchannel('A')
    solid = a.point(lambda v: 255 if v > 200 else 0)
    inner = solid.filter(ImageFilter.MinFilter(5))
    outline = ImageChops.subtract(solid, inner)
    w, h = im.size
    # chrome: bright top, a dark band under the middle, light again at the bottom
    grad = Image.new('RGB', (1, h))
    ys = [(0.0, (250, 251, 253)), (0.42, (170, 172, 178)), (0.55, rim_dark), (0.7, (120, 122, 128)), (1.0, (235, 236, 240))]
    for y in range(h):
        f = y / max(1, h - 1)
        for (p0, c0), (p1, c1) in zip(ys, ys[1:]):
            if p0 <= f <= p1:
                t = (f - p0) / (p1 - p0)
                grad.putpixel((0, y), tuple(round(c0[i] + (c1[i] - c0[i]) * t) for i in range(3)))
                break
    grad = grad.resize((w, h))
    out = Image.new('RGBA', (w, h), (0, 0, 0, 0))
    if shadow:
        sh = Image.new('RGBA', (w, h), shadow + (0,))
        sh.putalpha(solid.filter(ImageFilter.GaussianBlur(6)).point(lambda v: v * 0.55))
        out.alpha_composite(sh, (0, 5))
    body = Image.new('RGBA', (w, h), fill + (255,))
    body.putalpha(inner)
    out.alpha_composite(body)
    rim = grad.convert('RGBA')
    rim.putalpha(outline)
    out.alpha_composite(rim)
    out.save(dst)


def build(name, source, fn, bgdir):
    src, dst = THEMES / source, THEMES / name
    dst.mkdir(exist_ok=True)
    (dst / 'backgrounds').mkdir(exist_ok=True)
    for f in ('colors.toml', 'neovim.lua', 'shell.bar.toml', 'shell.launcher.toml', 'shell.menu.toml'):
        text = (src / f).read_text()
        text = recolor_rgba(recolor_text(text, fn), fn)
        text = text.replace('Tusche – Tusche & Papier (design round 02.10.2026)', 'Chrom – the metal family (design round 07.10.2026)')
        text = text.replace('Papier – Tusche & Papier (design round 02.10.2026)', 'Platin – the metal family (design round 07.10.2026)')
        (dst / f).write_text(text)
    colors = (dst / 'colors.toml').read_text()
    if name == 'chrom':
        colors = re.sub(r'hyprland_active_border = .*', 'hyprland_active_border = "rgba(f2f3f7ff) rgba(8a8c92ff) rgba(3b3c41ff) rgba(8a8c92ff) rgba(f2f3f7ff) 90deg"', colors)
        colors = re.sub(r'hyprland_inactive_border = .*', 'hyprland_inactive_border = "rgba(26272aff)"', colors)
    else:
        colors = re.sub(r'hyprland_active_border = .*', 'hyprland_active_border = "rgba(1a1b1dff) rgba(7a7d82ff) rgba(c9ccd0ff) rgba(7a7d82ff) rgba(1a1b1dff) 90deg"', colors)
        colors = re.sub(r'hyprland_inactive_border = .*', 'hyprland_inactive_border = "rgba(b0b3b8ff)"', colors)
    (dst / 'colors.toml').write_text(colors)
    (dst / 'hyprland.lua').write_text(HYPR[name])
    (dst / 'bar-material.json').write_text(json.dumps(MATERIAL[name], indent=2) + '\n')
    shutil.copy(src / 'icons.theme', dst / 'icons.theme')
    (dst / '.tusche-papier').write_text(MARK)
    if name == 'chrom':
        chrome_symbols(src / 'unlock.png', dst / 'unlock.png', (2, 2, 3), (58, 59, 64))
    else:
        chrome_symbols(src / 'unlock.png', dst / 'unlock.png', (225, 227, 230), (52, 54, 58), shadow=(26, 27, 30))
    if bgdir:
        for old in (dst / 'backgrounds').glob('*.jpg'):
            old.unlink()
        for s, d in BACKGROUNDS[name]:
            im = Image.open(Path(bgdir) / s).convert('RGB')
            if im.width < 1920:
                im = im.resize((1920, round(im.height * 1920 / im.width)), Image.LANCZOS)
            im.save(dst / 'backgrounds' / d, quality=94)
    print('built', dst)


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument('--backgrounds')
    a = ap.parse_args()
    build('chrom', 'tusche', chrom, a.backgrounds)
    build('platin', 'papier', platin, a.backgrounds)


if __name__ == '__main__':
    main()
