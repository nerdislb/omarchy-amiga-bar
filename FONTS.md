# NerdWorkbench typography

Private integration, not a claim of original authorship of the text glyphs.
The text fonts derive from [Screwtape's Topaz Unicode](https://gitlab.com/Screwtapello/topaz-unicode).
The vendored README/LICENSE snapshot is commit
`cd250227581720b52233292763ef5d7379196e11`; the prebuilt fonts were downloaded
from the `main/build` artifact. This is not an independently verified source
build of that commit. Source binary hashes are in `assets/fonts/unicode/SOURCE.json`.
We use the offered ISC license, reproduced with the fonts; we do not rely on
upstream's general statement about copyright of bitmap typefaces.

## Families

- **NerdWorkbench Mono:** 12×16 base cell, Regular and Bold.
- **NerdWorkbench UI:** 14×16 base cell, Regular and Bold.
- Text fonts contain 1004 mapped codepoints, including German umlauts, euro,
  arrows, box drawing, Greek and Cyrillic. They are not full Unicode fonts.
- Proportions are in the outlines, replacing the former per-widget horizontal
  stretching. At fractional sizes/scales rasterization may soften pixel edges.
- **NerdWorkbench Icons:** 12 original 8×8 pixel drawings at existing private-use
  icon positions. This is deliberately a small fallback, not a complete Nerd Font.
  These drawings use the separate MIT license in `LICENSE-ICONS`.

## Build

Use an isolated Python environment with `fonttools==4.66.1`, then run
`python tools/build-fonts.py`. No network is needed for generation from the
vendored inputs. Generated files and hashes are in `assets/fonts/nerdworkbench`.
The companion Island carries copies of UI Regular/Bold and the ISC license.
Deploy fonts through `bin/system-font.py enable`, which skips identical files
and atomically replaces changed files. **Never copy over a live font inode**:
FreeType can retain mmap readers, so an in-place truncation can crash consumers.

Original classic Topaz files are retained for provenance/compatibility; the new
profile uses NerdWorkbench. Publication remains deferred.
