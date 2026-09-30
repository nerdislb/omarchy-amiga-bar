#!/usr/bin/env python3
"""Build NerdWorkbench: Topaz Unicode on a whole-pixel 12x16 cell, with pixel icons.

    uv run --with fonttools==4.66.1 --with pillow==12.3.0 --with numpy==2.5.3 \
        python tools/build-fonts.py [--island ../omarchy-amiga-island] [--sheet out.png --cps f0079,...]

Design rules (see FONTS.md):
- One brick system. Topaz's 8x8 source pixels become 1.5x2 px bricks at
  16 px; column edges are snapped to whole pixels (widths 1,2,1,2,...), so
  every outline edge lies on the pixel grid at 16 and 32 px and renders
  crisp even with antialiasing.
- Icons use the same bricks: 11 columns x 8 rows = 16x16 px ink, 18 px
  advance. Nerd Font symbols are pixelated automatically; the icons the bar,
  island and menus use are drawn by hand in tools/icons/overrides.txt.
- Icons are merged into NerdWorkbench Mono (no fallback lottery) and also
  shipped alone as NerdWorkbench Icons for font routing.
"""
from pathlib import Path
import argparse
import hashlib
import json
import math
import shutil

import numpy as np
from fontTools.fontBuilder import FontBuilder
from fontTools.pens.ttGlyphPen import TTGlyphPen
from fontTools.ttLib import TTFont, newTable
from fontTools.ttLib.tables._c_m_a_p import CmapSubtable
from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
SRC = ROOT / 'assets/fonts/unicode'
OUT = ROOT / 'assets/fonts/nerdworkbench'
OVERRIDES = ROOT / 'tools/icons/overrides.txt'
NERD_FONT = Path('/usr/share/fonts/TTF/JetBrainsMonoNerdFont-Regular.ttf')
OMARCHY_FONT = Path('/usr/share/fonts/omarchy/omarchy.ttf')
EPOCH = 3863164800  # reproducible head.created/modified

UPEM = 1600          # 100 units = 1 px at 16 px
ASC, DESC = 1400, 200
CELL = 1200          # 12 px text cell
ICON_ADV = 1800      # 18 px icon advance
ICON_COLS, ICON_ROWS = 11, 8

# Nerd Font ranges to pixelate. Powerline separators and the progress-bar
# pieces stay out: they must tile the cell exactly.
NERD_RANGES = [
    ('pomicons', 0xE000, 0xE00A), ('fa-extension', 0xE200, 0xE2A9),
    ('weather', 0xE300, 0xE3E3), ('seti', 0xE5FA, 0xE6B7),
    ('devicons', 0xE700, 0xE8EF), ('codicons', 0xEA60, 0xEC1E),
    ('font-awesome', 0xED00, 0xF2FF), ('font-logos', 0xF300, 0xF381),
    ('octicons', 0xF400, 0xF533), ('material-design', 0xF0001, 0xF1AF0),
]
OMARCHY_RANGE = ('omarchy', 0xE900, 0xE90E)


def col_x(c):
    """Left edge (font units) of brick column c: whole pixels, 1.5 px pitch."""
    return math.floor(1.5 * c) * 100


# --------------------------------------------------------------- outlines
def trace(grid, xs, ys):
    """Union of on-cells -> TrueType contours (clockwise outer, y-up).

    grid[r][c] with r from the top; xs/ys map grid lines to font units.
    """
    rows, cols = len(grid), len(grid[0])
    on = lambda r, c: 0 <= r < rows and 0 <= c < cols and grid[r][c]
    edges = {}
    for r in range(rows):
        for c in range(cols):
            if not on(r, c):
                continue
            # Directions chosen so the filled side is on the right in y-up
            # font space (TrueType's clockwise outer contours).
            if not on(r - 1, c): edges.setdefault((c + 1, r), []).append((c, r))
            if not on(r, c - 1): edges.setdefault((c, r), []).append((c, r + 1))
            if not on(r + 1, c): edges.setdefault((c, r + 1), []).append((c + 1, r + 1))
            if not on(r, c + 1): edges.setdefault((c + 1, r + 1), []).append((c + 1, r))
    contours = []
    while edges:
        start = next(iter(edges))
        loop, p = [start], start
        while True:
            nxt = edges[p].pop()
            if not edges[p]:
                del edges[p]
            if nxt == start:
                break
            loop.append(nxt)
            p = nxt
        pts = []
        n = len(loop)
        for i in range(n):
            a, b, d = loop[i - 1], loop[i], loop[(i + 1) % n]
            if (a[0] == b[0] == d[0]) or (a[1] == b[1] == d[1]):
                continue  # collinear
            pts.append((xs[b[0]], ys[b[1]]))
        contours.append(pts)
    return contours


def draw(contours):
    pen = TTGlyphPen(None)
    for pts in contours:
        pen.moveTo(pts[0])
        for p in pts[1:]:
            pen.lineTo(p)
        pen.closePath()
    return pen.glyph()


ICON_XS = [100 + col_x(c) for c in range(ICON_COLS + 1)]          # 1 px bearing
ICON_YS = [ASC - 200 * r for r in range(ICON_ROWS + 1)]


def icon_glyph(grid):
    return draw(trace(grid, ICON_XS, ICON_YS))


# --------------------------------------------------------------- pixelating
def render_mask(font, cp, size=256):
    im = Image.new('L', (size * 2, size * 2), 0)
    ImageDraw.Draw(im).text((size // 2, size * 3 // 2), chr(cp), font=font, fill=255, anchor='ls')
    a = np.asarray(im, dtype=np.float32) / 255.0
    ys, xs = np.nonzero(a > 0.08)
    if not len(xs):
        return None
    return a[ys.min():ys.max() + 1, xs.min():xs.max() + 1]


BRICK_X = np.array([1.5 * c for c in range(ICON_COLS + 1)])
BRICK_Y = np.array([2.0 * r for r in range(ICON_ROWS + 1)])


def pixelate(mask, full_h, threshold=0.42):
    """Fit a glyph (typical full height full_h) into 11x8 bricks of 1.5x2 px.

    Thin strokes straddling two bricks would vanish at a fixed alignment, so
    a few sub-brick offsets are tried and the grid with the least shape error
    (wrong bricks + ink lost outside the box) wins.
    """
    h, w = mask.shape
    box_w, box_h = ICON_COLS * 1.5, ICON_ROWS * 2.0
    s = min(15.0 / full_h, box_w / w, box_h / h)
    integral = np.zeros((h + 1, w + 1))
    integral[1:, 1:] = mask.cumsum(0).cumsum(1)
    total = integral[-1, -1]
    brick_area = (1.5 / s) * (2.0 / s)
    best = None
    for dx in (-0.75, -0.5, -0.25, 0.0, 0.25, 0.5, 0.75):
        for dy in (-1.0, -0.5, 0.0, 0.5, 1.0):
            ox, oy = (box_w - w * s) / 2 + dx, (box_h - h * s) / 2 + dy
            xe = np.clip(np.rint((BRICK_X - ox) / s), 0, w).astype(int)
            ye = np.clip(np.rint((BRICK_Y - oy) / s), 0, h).astype(int)
            sums = (integral[np.ix_(ye[1:], xe[1:])] - integral[np.ix_(ye[:-1], xe[1:])]
                    - integral[np.ix_(ye[1:], xe[:-1])] + integral[np.ix_(ye[:-1], xe[:-1])])
            cov = sums / brick_area
            grid = cov > threshold
            lost = total - sums.sum()
            err = np.where(grid, 1 - cov, cov).sum() * brick_area + lost
            if best is None or err < best[0] - 1e-6:
                best = (err, grid)
    return best[1].tolist()


def auto_icons():
    icons, provenance = {}, {}
    sources = [(NERD_FONT, NERD_RANGES), (OMARCHY_FONT, [OMARCHY_RANGE])]
    for path, ranges in sources:
        if not path.exists():
            raise SystemExit(f'missing icon source {path}')
        tt = TTFont(path)
        cmap = tt.getBestCmap()
        pil = ImageFont.truetype(str(path), 256)
        provenance[path.name] = hashlib.sha256(path.read_bytes()).hexdigest()
        for name, lo, hi in ranges:
            masks = {cp: render_mask(pil, cp) for cp in cmap if lo <= cp <= hi}
            masks = {cp: m for cp, m in masks.items() if m is not None}
            if not masks:
                continue
            # A set's "full" icon height: most icons in a set share one box.
            full_h = float(np.percentile([max(m.shape) for m in masks.values()], 90))
            for cp, m in masks.items():
                icons[cp] = pixelate(m, full_h)
    return icons, provenance


def parse_overrides():
    """tools/icons/overrides.txt: 'U+F0079 name' then 8 rows of 11 '#'/'.'."""
    out, cp, rows = {}, None, []
    if not OVERRIDES.exists():
        return out
    for line in OVERRIDES.read_text().splitlines():
        s = line.strip()
        if s.lower().startswith('u+'):
            cp, rows = [int(tok[2:], 16) for tok in s.split() if tok.lower().startswith('u+')], []
            continue
        if cp is not None and s and set(s) <= set('#.'):
            rows.append(s)
            if len(rows) == ICON_ROWS:
                if any(len(r) != ICON_COLS for r in rows):
                    raise SystemExit(f'override U+{cp[0]:X}: rows must be {ICON_COLS} wide')
                for code in cp:
                    out[code] = [[ch == '#' for ch in r] for r in rows]
                cp = None
    return out


# Horizontal batteries: 10x6 body, 8 fill columns, terminal on the right.
# Charging adds a bolt that inverts over the fill.
BATTERY = {0xF008E: 0, 0xF007A: 10, 0xF007B: 20, 0xF007C: 30, 0xF007D: 40, 0xF007E: 50,
           0xF007F: 60, 0xF0080: 70, 0xF0081: 80, 0xF0082: 90, 0xF0079: 100,
           0xF244: 0, 0xF243: 25, 0xF242: 50, 0xF241: 75, 0xF240: 100}
BATTERY_CHARGING = {0xF089F: 0, 0xF089C: 10, 0xF0086: 20, 0xF0087: 30, 0xF0088: 40, 0xF089D: 50,
                    0xF0089: 60, 0xF089E: 70, 0xF008A: 80, 0xF008B: 90, 0xF0085: 100, 0xF0084: 100}
BOLT = {(2, 5), (2, 6), (3, 3), (3, 4), (3, 5), (4, 4), (4, 5), (4, 6), (5, 3), (5, 4)}


def battery(level, charging=False, alert=False):
    grid = [[False] * ICON_COLS for _ in range(ICON_ROWS)]
    for c in range(10):
        grid[1][c] = grid[6][c] = True
    for r in range(1, 7):
        grid[r][0] = grid[r][9] = True
    grid[3][10] = grid[4][10] = True
    fill = round(level * 8 / 100)
    for r in range(2, 6):
        for c in range(1, 1 + fill):
            grid[r][c] = True
    if charging:
        for r, c in BOLT:
            grid[r][c] = not grid[r][c]
    if alert:
        for r in (2, 3, 5):
            grid[r][4] = grid[r][5] = True
    return grid


def battery_icons():
    icons = {cp: battery(level) for cp, level in BATTERY.items()}
    icons.update({cp: battery(level, charging=True) for cp, level in BATTERY_CHARGING.items()})
    icons[0xF0083] = battery(0, alert=True)   # battery-alert
    return icons


# --------------------------------------------------------------- fonts
def set_cmap(font, mapping):
    bmp = {cp: g for cp, g in mapping.items() if cp <= 0xFFFF}
    tables = []
    for pid, eid, fmt, m in [(0, 3, 4, bmp), (3, 1, 4, bmp), (0, 4, 12, mapping), (3, 10, 12, mapping)]:
        t = CmapSubtable.newSubtable(fmt)
        t.platformID, t.platEncID, t.language, t.cmap = pid, eid, 0, dict(m)
        tables.append(t)
    font['cmap'] = newTable('cmap')
    font['cmap'].tableVersion = 0
    font['cmap'].tables = tables


def names(font, family, style):
    values = {
        0: 'Topaz Unicode (c) Screwtape, ISC; NerdWorkbench grid and pixel icons (c) 2026 Nerdibeard',
        1: family, 2: style, 3: f'{family} {style} 2.0', 4: f'{family} {style}',
        5: 'Version 2.0', 6: f'{family}-{style}'.replace(' ', ''), 16: family, 17: style,
        8: 'Nerdibeard', 9: 'Screwtape (Topaz Unicode); Nerdibeard (grid, icons)',
        13: 'Text glyphs: ISC (Topaz Unicode, see LICENSE). Pixel icons: see LICENSE-ICONS.',
    }
    for key in list({n.nameID for n in font['name'].names}):
        if key not in values:
            font['name'].removeNames(nameID=key)
    for key, value in values.items():
        font['name'].removeNames(nameID=key)
        font['name'].setName(value, key, 3, 1, 0x409)


def text_font(style, icons):
    f = TTFont(SRC / f'topaz_unicode_ks13_{style.lower()}.ttf', recalcTimestamp=False)
    f['glyf'].removeHinting()
    for tag in ('fpgm', 'prep', 'cvt ', 'hdmx', 'LTSH', 'VDMX'):
        if tag in f:
            del f[tag]
    glyf, hmtx = f['glyf'], f['hmtx']
    for name in f.getGlyphOrder():
        g = glyf[name]
        if g.numberOfContours > 0:
            g.coordinates = type(g.coordinates)([(col_x(x // 100), y) for x, y in g.coordinates])
            g.recalcBounds(glyf)
        width, _ = hmtx[name]
        hmtx[name] = (col_x(width // 100), g.xMin if g.numberOfContours > 0 else 0)
    cmap = dict(f.getBestCmap())
    # Topaz's own private-use glyphs would mask Nerd/Font Awesome icons.
    cmap = {cp: g for cp, g in cmap.items() if not (0xE000 <= cp <= 0xF8FF or cp >= 0xF0000)}
    if 0x2715 not in cmap and 0xD7 in cmap:
        cmap[0x2715] = cmap[0xD7]
    order = list(f.getGlyphOrder())
    for cp, grid in sorted(icons.items()):
        name = f'icon{cp:05X}'
        order.append(name)
        g = icon_glyph(grid)
        glyf.glyphs[name] = g
        g.recalcBounds(glyf)
        hmtx[name] = (ICON_ADV, g.xMin if g.numberOfContours else 0)
        cmap[cp] = name
    f.setGlyphOrder(order)
    glyf.glyphOrder = order
    set_cmap(f, cmap)
    f['post'].formatType = 3.0
    f['post'].isFixedPitch = 1
    f['hhea'].advanceWidthMax = ICON_ADV
    os2 = f['OS/2']
    os2.xAvgCharWidth = CELL
    os2.fsType = 0
    os2.ulUnicodeRange2 |= 1 << (60 - 32)   # Private Use Area
    os2.ulUnicodeRange3 |= 1 << (90 - 64)   # Private Use (plane 15)
    f['maxp'].numGlyphs = len(order)
    f['head'].created = f['head'].modified = EPOCH
    names(f, 'NerdWorkbench Mono', style)
    return f


def icon_font(icons):
    order = ['.notdef'] + [f'icon{cp:05X}' for cp in sorted(icons)]
    fb = FontBuilder(UPEM, isTTF=True)
    fb.setupGlyphOrder(order)
    glyphs = {'.notdef': TTGlyphPen(None).glyph()}
    for cp in sorted(icons):
        glyphs[f'icon{cp:05X}'] = icon_glyph(icons[cp])
    fb.setupCharacterMap({cp: f'icon{cp:05X}' for cp in icons})
    fb.setupGlyf(glyphs)
    metrics = {}
    for name in order:
        g = fb.font['glyf'][name]
        metrics[name] = (ICON_ADV, g.xMin if g.numberOfContours else 0)
    fb.setupHorizontalMetrics(metrics)
    fb.setupHorizontalHeader(ascent=ASC, descent=-DESC)
    fb.setupOS2(sTypoAscender=ASC, sTypoDescender=-DESC, sTypoLineGap=0,
                usWinAscent=ASC, usWinDescent=DESC, fsType=0, xAvgCharWidth=ICON_ADV,
                ulUnicodeRange2=1 << (60 - 32), ulUnicodeRange3=1 << (90 - 64))
    fb.setupNameTable({'familyName': 'NerdWorkbench Icons', 'styleName': 'Regular'})
    fb.setupPost(formatType=3.0)
    fb.setupMaxp()
    fb.font['head'].created = fb.font['head'].modified = EPOCH
    names(fb.font, 'NerdWorkbench Icons', 'Regular')
    fb.font.recalcTimestamp = False
    return fb.font


# --------------------------------------------------------------- review sheet
def sheet(path, cps, font_path, scale=3):
    """Pixel-exact (non-antialiased) 16 px review sheet of the given codepoints."""
    pil = ImageFont.truetype(str(font_path), 16)
    per_row = 24
    rows = (len(cps) + per_row - 1) // per_row
    im = Image.new('L', (per_row * 30 + 8, rows * 34 + 8), 24)
    d = ImageDraw.Draw(im)
    d.fontmode = '1'
    tiny = ImageFont.load_default()
    for i, cp in enumerate(cps):
        x, y = 4 + (i % per_row) * 30, 4 + (i // per_row) * 34
        d.text((x + 4, y + 16), chr(cp), font=pil, fill=235, anchor='ls')
        d.text((x, y + 20), f'{cp:X}'[-4:], font=tiny, fill=110)
    im.resize((im.width * scale, im.height * scale), Image.NEAREST).save(path)


def main():
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument('--island', type=Path, help='Also refresh the Amiga Island font copies.')
    ap.add_argument('--sheet', type=Path, help='Write a review sheet of the codepoints in --cps.')
    ap.add_argument('--cps', default='', help='Comma-separated hex codepoints for --sheet.')
    ap.add_argument('--sheet-only', action='store_true', help='Only render the sheet from the built fonts.')
    args = ap.parse_args()

    if args.sheet_only:
        sheet(args.sheet, [int(x, 16) for x in args.cps.split(',') if x.strip()], OUT / 'NerdWorkbenchMono-Regular.ttf')
        return
    icons, provenance = auto_icons()
    overrides = parse_overrides()
    overrides.update(battery_icons())
    icons.update(overrides)
    OUT.mkdir(exist_ok=True)
    for stale in ['NerdWorkbenchUI-Regular.ttf', 'NerdWorkbenchUI-Bold.ttf']:
        (OUT / stale).unlink(missing_ok=True)
    for style in ['Regular', 'Bold']:
        text_font(style, icons).save(OUT / f'NerdWorkbenchMono-{style}.ttf')
    icon_font(icons).save(OUT / 'NerdWorkbenchIcons.ttf')
    (OUT / 'LICENSE').write_text(
        'NerdWorkbench text glyphs are derived from Topaz Unicode by Screwtape\n'
        '(https://gitlab.com/Screwtapello/topaz-unicode), which offers the ISC licence\n'
        'reproduced below. Copyright notices for this derivative:\n\n'
        'Copyright (c) Screwtape (Topaz Unicode)\n'
        'Copyright (c) 2026 Nerdibeard (whole-pixel 12x16 grid, packaging)\n\n'
        + (SRC / 'LICENSE').read_text())
    manifest = {
        'fonts': {p.name: hashlib.sha256(p.read_bytes()).hexdigest() for p in sorted(OUT.glob('*.ttf'))},
        'iconSources': provenance,
        'icons': {'total': len(icons), 'handDrawn': len(overrides)},
    }
    (OUT / 'SHA256.json').write_text(json.dumps(manifest, indent=2) + '\n')
    if args.island:
        dest = args.island / 'assets/fonts/nerdworkbench'
        dest.mkdir(parents=True, exist_ok=True)
        for old in dest.glob('NerdWorkbenchUI-*.ttf'):
            old.unlink()
        for name in ['NerdWorkbenchMono-Regular.ttf', 'NerdWorkbenchMono-Bold.ttf', 'LICENSE', 'LICENSE-ICONS']:
            if (OUT / name).exists():
                shutil.copyfile(OUT / name, dest / name)
    if args.sheet:
        sheet(args.sheet, [int(x, 16) for x in args.cps.split(',') if x.strip()], OUT / 'NerdWorkbenchMono-Regular.ttf')
    print(json.dumps(manifest, indent=2))


if __name__ == '__main__':
    main()
