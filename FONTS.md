# NerdWorkbench typography

Private integration, not a claim of original authorship of the text glyphs.
The text glyphs derive from [Screwtape's Topaz Unicode](https://gitlab.com/Screwtapello/topaz-unicode).
The vendored README/LICENSE snapshot is commit
`cd250227581720b52233292763ef5d7379196e11`; the prebuilt fonts were downloaded
from the `main/build` artifact. This is not an independently verified source
build of that commit. Source binary hashes are in `assets/fonts/unicode/SOURCE.json`.
We use the offered ISC licence, reproduced with the fonts with a copyright line
naming Screwtape (upstream's LICENSE has none); we do not rely on upstream's
general statement about copyright of bitmap typefaces.

## One brick system

- **NerdWorkbench Mono** (Regular, Bold) is the only text family. Topaz's 8×8
  source pixels become 1.5×2 px bricks on a **12×16 px cell at 16 px**; column
  edges are snapped to whole pixels (widths 1, 2, 1, 2 …). Every outline edge
  lies on the pixel grid at 16 and 32 px, so it renders crisp even with
  antialiasing. At other sizes it cannot be crisp, which is why the Amiga Bar,
  the Island and the desktop profile snap all text to 16 (or 32) px.
- **Icons use the same bricks**: 11 columns × 8 rows = 16×16 px ink with an
  18 px advance. They are merged into NerdWorkbench Mono (text and icons from
  one font, no fallback lottery) and also shipped alone as
  **NerdWorkbench Icons**, which the desktop profile puts in front of requests
  for `Symbols Nerd Font` and the `omarchy` logo font.
- The Nerd Font ranges (Material Design, Font Awesome, Codicons, Octicons,
  Devicons, Seti, Weather, Font Logos, Pomicons, FA extension) and the Omarchy
  glyphs are pixelated automatically: each glyph is fitted into the brick grid
  at the offset with the least shape error, so thin strokes survive.
  Powerline separators and progress pieces are left out (they must tile a cell).
- The icons the bar, island, menus and native Omarchy widgets show most are
  drawn by hand in `tools/icons/overrides.txt` (weather, clock, volume,
  microphone, keyboard, chip, radar, VPN, Omarchy logo …); batteries are
  generated (horizontal, 8 fill steps, bolt for charging). One meaning has one
  picture: aliases give MDI and Font Awesome variants the same drawing.
- Topaz's own private-use glyphs are dropped from the text font so they cannot
  mask Nerd/Font Awesome icons. The text font maps 1000 codepoints (Latin
  incl. umlauts, euro, arrows, box drawing, Greek, Cyrillic, plus ✦ drawn for
  the Island) and 10,370 icons.

## Build

```sh
uv run --with fonttools==4.66.1 --with pillow==12.3.0 --with numpy==2.5.3 \
    python tools/build-fonts.py --island ../omarchy-amiga-island
# review sheet of given codepoints (16 px, non-antialiased, 3x):
uv run --with fonttools==4.66.1 --with pillow==12.3.0 --with numpy==2.5.3 \
    python tools/build-fonts.py --sheet-only --sheet /tmp/icons.png --cps f0079,f057e,e30d
```

Icon inputs are the locally installed `JetBrainsMonoNerdFont-Regular.ttf` and
Omarchy's `omarchy.ttf`; their SHA-256 are recorded in
`assets/fonts/nerdworkbench/SHA256.json` together with the output hashes.
Generated files are committed, so a rebuild is only needed after changing the
grid or the drawings. `--island` refreshes the Island's copies.

Deploy fonts through `bin/system-font.py enable`, which skips identical files
and atomically replaces changed ones. **Never copy over a live font inode**:
FreeType can keep an mmap reader, so an in-place truncation can crash consumers
(quickshell SIGSEGV on 2026-09-30). Unlinking and renaming are safe.

## Licences and publication status

- Text glyphs: ISC (Topaz Unicode), `assets/fonts/nerdworkbench/LICENSE`.
- Hand-drawn icons: MIT, `LICENSE-ICONS` part 1.
- Pixelated Nerd Font / Omarchy glyphs: derivatives of their original sets;
  `LICENSE-ICONS` part 2 lists each range and licence (OFL, CC BY, MIT,
  Apache/Pictogrammers, trademarked logos).
- **Private build.** Before a public release, re-check those terms (OFL sets
  may need a separate OFL font, CC BY sets need attribution, logos need
  trademark review) or ship only the hand-drawn icons. The former GPL-FE
  "Multi Platform Amiga Fonts" Topaz files are no longer used or shipped.
- The Amiga tick and Boing ball logos (`modules/PixelLogo.qml`) are pixel
  renditions of Amiga trademarks: fine for this private build, trademark
  review needed before a release.
