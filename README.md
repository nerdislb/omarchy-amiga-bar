# Amiga Bar (private build)

Presets and compact Amiga-style modules for the **native** Omarchy bar. See `ROADMAP.md` for stages A–E.

## Architecture
- `Engine.qml` — keep-loaded panel plugin (`nerdibeard.amiga-bar`): Control Center, presets, IPC. It writes `bar.layout` through `bin/apply-layout.py` (atomic, keeps shell.json's 0600 mode). The bar itself stays `omarchy.bar`.
- Why not a replacement bar: under a plugin bar, Omarchy hands third-party widgets a service-less shell facade (security boundary), so OmaMail, WhatsApp and Flux lose their own services. Tried in stage A, reverted.
- Own parts are custom QML modules in the layout (`{ "id": "amiga.x", "source": "<plugin>/modules/X.qml", ... }`); one plugin can register only one bar widget.
- `modules/Status.qml` mounts the widgets it folds away invisibly (`embeds`: id → original settings), so their native popups (Wi-Fi, Bluetooth, VPN, Tailscale, monitor, drive, radar, plugins, buds, system monitor) still open from our groups/drawer. Flux, OmaMail and WhatsApp are not embedded (they need their own services); Flux is read via `flux-cli` and opened as its window. Weather and world clocks stay native (their popups position via the centre section).
- The user's layout is captured once in `~/.local/state/amiga-bar/base.json`; "Heute" restores it. Options live in this plugin's `plugins[]` entry.

## Elements and variants
| Element | Variants |
|---|---|
| Workspaces (`Workspaces.qml`, incl. Omarchy logo) | today, pips, stack, logo, minimap, cli, boing |
| AI quotas (`Quota.qml`) | today, gauge, vu, rings, ondemand, title (Workbench title line) |
| Right side (`Status.qml`) | today, groups, deviations, drawer (Workbench window), hardware (A500 strip), compact (A500 strip, compact) — in groups/deviations the system group shows a chip outline (the phone glyph's 2 px stroke) that fills from below like the battery (CPU in 6 rows, one row from 2 %); CPU > 85 % or RAM > 90 % turns only the fill to the alarm tone |
| Bar edge (`WorkbenchEdge.qml`, `ThemeEdge.qml`) | none (default), workbench (Workbench edge), theme (light & shadow from the theme's `bar-material.json`) — kept by presets |
| Bar form (`A500Case.qml`) | full (default), a500 (A500 case edge) — kept by presets |
| Fog look (test) (`FogEdge.qml`, `FogPanel.qml`, `FogLayer.qml`) | off (default), on — kept by presets |
| Logo menu (`DropMenu.qml`, `IntuitionMenu.qml`) | drop (default, drop-down under the logo), strip (menu strip) — kept by presets |
| Logo (`PixelLogo.qml`, `ArchLogo.qml`, `SealLogo.qml`) | omarchy, arch (the official Arch Linux mark, unaltered, in the bar's ink), nerdibeard (the seal: nb cut out of a 16 px ink block), amiga (rainbow double tick), boing (Boing ball) — amiga/boing drawn in the pixel font's brick grid with theme colours; with native workspaces only the menu logo is replaced; the drop-down's title follows the logo (ARCH LINUX, NERDIBEARD) |
| Centre (`Centre.qml`) | today, calm (temperature at the weather glyph) |
| Pixel font (NerdWorkbench) | theme · topaz = Amiga moments (menu strip, status screen, Workbench window title, requester, Guru strip, title line) · bar = all Amiga Bar and Island text and icons · desktop = bar + the reversible desktop profile |
| Events | plain, amiga (Boing ball, copper progress; read by the island) |

Presets: `heute`, `k1` (pips · gauge · groups), `k2` (logo · VU · drawer · pixel font for bar & island), `k3` (stack · on demand · deviations).
Presets and saved combinations never switch the desktop font profile: while it is on they keep `desktop`, otherwise a saved `desktop` loads as `bar`.

**A500 strip, compact** (`right: compact`) keeps labelled CPU/RAM VU columns,
POWER and DF0 LEDs in about 132–168 px at 1×, followed by the drawer cell.
Click either meter/body cell or the drawer for the full Workbench popup;
POWER opens battery/power and DF0 opens Flux. DF0 lights amber during disk
activity and stays lit while a USB phone is detected. It folds the same widgets
as `hardware`, without the separate phone-name slot.

**Workbench edge** (`edge: workbench`) adds a highlight and shadow, each one
device pixel, over the bottom of the native top bar on every monitor. It follows
the live bar size, visibility and theme, accepts no input and reserves no space.
It hides for bottom/side bars, and is removed when set to `none` or when the
plugin unloads. Existing presets and older saved combinations default to `none`.
Both options are available in Options and through `amiga-bar set right compact`
or `amiga-bar set edge workbench` with the usual `omarchy-shell` prefix.

**Edge from the theme** (`edge: theme`) reads `bar-material.json` from the
current Omarchy theme (the Tusche & Papier themes ship one; other themes show
no edge) and follows theme switches. `edge.kind` `dry`: a line over the bar's
lower edge on Overlay (light in Tusche, ink in Papier), and under it a short
hard shadow, a glow and a still haze on the Top layer — while the workspace
has windows only in the gap above them (`general:gaps_out`), in full on an
empty one (on the Bottom layer Hyprland here blends layer surfaces
additively, so a dark haze would never show). `kind` `lavur`: a pre-rendered
wash (`bar-lavur.png` in the theme) instead. With the material, popups (drop
menu, quota, status) roll out of the bar from the top in the theme's frame
with its shadow (Papier: hard ink, 6/6) or halo (Tusche, Lavur), hanging
flush from the bar; the logo becomes an inverted tab while the drop menu is
open, and the hovered row inverts. A material card with `bloom` (the Lavur
themes) blooms instead of rolling: the fog's growth out of the bar as one
sheet of wet paper (`InkSheet.qml`). Ink fills it (in the tide colour,
`tide`), the water clears it from the source (`shaders/wetink.frag`) and its
residue evaporates with the water; the pigment dries into a rim at the calm
edge – a blurred blob cut at a gently noise-displaced threshold
(`shaders/bloomcut.frag`), the rim just inside it gathered in a few short
denser sections, a broken faint drying line further in
(`shaders/restink.frag`, over the paper's mask blurred by
`shaders/gauss.frag`); all noise in the card's own coordinates. Under it a
halo: Papier a short soft ink wash, Tusche a flat dark seam plus a breath of
moonlight. The theme tunes it with `card.rest` (`ridge`, `pool`, `echo`,
`residue`, `halo` parts with `color`, `alpha`, `blur` = σ in px, `dx`, `dy`,
`spread`, `dh`). The compiled `.qsb` files ship next to the shaders; rebuild
one with `qsb --glsl "100 es,120,150" --hlsl 50 --msl 12 -o shaders/X.frag.qsb shaders/X.frag`.
The drop menu's hover is
then a brush stroke (`brush`, a PNG in the theme folder). With `tones.strong`
the bar's own text is the quieter tone (the theme sets it) and logo and the
active workspace's number stay strong. The fog look replaces all of it while
on. `amiga-bar set edge theme`
(or `none`) with the usual `omarchy-shell` prefix; the Amiga Island takes the
same material for its notes.

**A500 case edge** (`form: a500`) turns the bar into the top edge of an Amiga
500 inside the normal bar height: a flat top face, the darker wedge front with
a light crease, cooling grooves left of the island, an LED window around the
compact strip and the drive slot under the island; DF0 lights while a note
comes out of it (the island publishes its span and a note flag in
`~/.local/state/omarchy/amiga-island/bar-span.json`). The native bar stays the
bar: `bin/bar-form.py` keeps one managed block in `~/.config/omarchy/shell.toml`
(`[bar] background-alpha = 0.0`, between `# >>> amiga-bar form` markers) so its
own fill is transparent while its text keeps the theme colour, and the case is
drawn on the Bottom layer under it. `full` removes the block; so does removing
or disabling the plugin (checked 4 s after the engine unloads). The block is
only written while the bar is the native one at the top, and never when the
file already defines a `[bar]` table (the script refuses rather than produce
invalid TOML). Manual undo: `python3 bin/bar-form.py disable`.

**Fog look (test)** (`fog: on`): the bar ends in soft, slightly lumpy fog
instead of a hard edge (replaces the Workbench edge while on), and everything
that opens from the bar grows out of it as fog — a drop falls out of the bar,
swells to the popup's size, then the content fades in; closing reverses and
leaves a faint fog for a moment. Covered: Amiga Island notes and its popup,
the Quota and Status popups, the Control Center. Omarchy's own popups (Wi-Fi,
audio, power, calendar …) keep their cards. The fog is a gooey layer
(`FogLayer.qml`: blur plus a soft alpha threshold with MultiEffect) in the
bar's colour, opaque, or the case's front colour with `form: a500`.
`FogPanel.qml` attaches to an Omarchy `KeyboardPanel` (declare it inside the
panel). Two Qt details shape the code: the effect chain is built only while
the layer is visible (a MultiEffect created hidden never drew), and shapes
change size, never just visibility (the hidden shape layer does not repaint
for that). Reduced Motion: shapes jump, the content fades.

AI usage records (`~/.local/state/omarchy/agents/usage`) are refreshed by
`omarchy.agents` only while it sits in the bar. When a variant folds the AI
widgets away, the engine runs `omarchy-agent-usage-update` itself with that
widget's interval and disabled providers (retrying advised limits after 30 s),
and fetches limits when the quota popup or status screen opens. A limit past
its reset time always counts as reset (0 %), in the bar, status screen and
island, even before a fresh record arrives.

## Logos: Arch and the Nerdibeard seal

From the logo design round of 04.10. (concept in the OpenClaw workspace,
`output/logo-runde-2026-10-04` and `output/logo-bewegung-2026-10-04`), in
the reviewed version: expressive only once, when the logo arrives (the bar
starts or the option switches to it), then still – no hover effect, no loop.

- `arch` (`modules/ArchLogo.qml`): the first path of
  `/usr/share/pixmaps/archlinux-logo.svg` (package filesystem) without the ™,
  one fill in the bar's strong ink, 1.18 × the 18 px field (the
  triangle reads lighter than a square glyph), centred like the Omarchy
  glyph. Arrival: one fade, 0.22 s (reduced motion 0.12 s). The tab inverts
  it. Arch's trademark policy (terms.archlinux.org/docs/trademark-policy)
  allows unaltered, non-commercial use that implies no endorsement: never
  alter its shape; check the policy again before any public release.
- `nerdibeard` (`modules/SealLogo.qml`): a 16 × 16 block with a 1 px rim and
  the initials nb cut out in squared seal script, whole pixels, its top line
  on the workspace frame's. Arrival: one impression, 0.32 s – the ink at the
  letters' edges prints at once, the rest soaks out to the rim in a fixed
  order (from the design's own code). Press: the ink takes the tab's tone.
  Drop-down (theme material): the ink runs out of the seal into the tab once
  (0.24 s, a rounded front, the nb readable throughout); closing restores the
  rest state once the card is back. Reduced motion: 0.12 s cross-fades.

Switch: Control Center → Logo, or `omarchy-shell amiga-bar set logo
omarchy|arch|nerdibeard|amiga|boing`.

## Boot screen logo (Plymouth)

`bin/boot-logo.py set nerdibeard|arch [--theme NAME]` puts the seal (a
finished stamp impression, a fifth smaller than the 230 px logo box, set a
touch crooked) or the unaltered Arch mark on the boot screen that asks for
the disk password, in the theme's foreground on its background (default: the
current theme). The marks come from the design's own code
(`assets/boot/*.alpha`, 240 × 240 alpha masks); the script composes the PNG
under `~/.local/state/amiga-bar/boot-logo/` and hands it to Omarchy's
`omarchy-plymouth-set`, which asks for the sudo password and rebuilds the
initramfs. `restore` puts the theme's own unlock.png back
(`omarchy-plymouth-set-by-theme`), `restore --default` Omarchy's logo;
`status` tells what the boot screen shows. The boot screen does not follow
the bar's logo option or theme switches by itself (each change needs sudo).
Static: the impression's motion from the design would need frame sequences
in Omarchy's `omarchy.script`. Test: `python3 tests/boot_logo.py`.

## fastfetch logo

`bin/fastfetch-logo.py enable` puts the Amiga rainbow double tick (half-block
cells, theme colours, rear tick darker) with AMIGA underneath into fastfetch:
it replaces only the `logo` object of `~/.config/fastfetch/config.jsonc`
(keeping its padding; the previous object is stored for `restore`), writes
`~/.config/fastfetch/amiga-logo.ansi` and installs the theme-set hook
`amiga-fastfetch-logo`, which recolours the logo on theme changes.
`restore` puts the previous logo back and removes file and hook; `status`
reports the state. Test: `python3 tests/fastfetch_logo.py`.

## Logo menu, menu strip and status screen
- `DropMenu.qml` (`menu: drop`, default): left click on the logo or **Super+Alt+M** folds out one tall menu under the logo (with the fog look it grows out of the bar as fog). On top the Omarchy menu itself — `omarchy-menu.jsonc` plus `~/.config/omarchy/extensions/omarchy-menu.jsonc`, read by `OmarchyMenuSource.qml` with Omarchy's own model library (`vendor/MenuModel.js`, unchanged copy) including `when:`/`checked:`/`disabled:` guards; below our groups Agents · Network · Phone · Widgets · Amiga. Submenus open inside it (‹ back), typing searches the whole tree and lists matching apps after the menu hits (at most 8); ↑↓, PgUp/PgDn, Enter/→, ←/Backspace, Esc. Right click on the logo: Omarchy's own centred menu.
- Nested like the native menu (0.7.0), so a pick in the drop-down never ends in the centred menu:
  - **Lists the shell fills in** open as levels inside it: **Apps** from the shell's application library (the facade Omarchy hands to plugins of kind `menu` — hence `"menu"` next to `"panel"` in `manifest.json`; the plugin still loads as the same keep-loaded panel), alphabetical with the apps' own icons, launched like the native menu; **Font** and power profiles with the native menu's own bash providers (copied, ✓ on the current value; fonts reload each time). Typing inside a list filters it (label and subtext). Without the library (older shell) or for an unknown provider the native menu opens there as before.
  - **Questions** an action asks through `omarchy-menu-select` / `omarchy-menu-input` (Keybindings, Tmux, Herdr, Timezone, the plugin rows, Remove › TUI/Theme/Web App, Transcode …) are answered inside it. Every Omarchy action started from the drop-down runs with `bin/menu-shim` first on its `PATH`; those two shims take the same arguments, stdin and file protocol as Omarchy's commands and hand the payload to `omarchy-shell amiga-bar ask`. When no drop-down takes it (no Amiga Bar, menu option `strip`, shell not answering) they run Omarchy's own command with the same prompt, options (stdin included) and menu arguments. An action known to ask (its first word is a script calling one of the two; screen captures excepted) keeps the drop-down open on a waiting level that turns into the question, or closes when the action ends without asking (at the latest after 3 s). A question that arrives with the drop-down closed opens it on the screen that had it last. The answer is written as the native menu writes it (the selection file, then the done file); Esc, ×, a click outside, ‹ and every other close cancel (the done file alone), so no script is ever left waiting. `amiga-bar state` shows `ask` (library present, pending questions, running asking actions).
- `IntuitionMenu.qml` (`menu: strip`): Omarchy · Agents · System · Network · Phone · Tools, opened by right click on the Omarchy logo or **Super+Alt+M**; arrows/Enter/Esc; toggles show ✓ (DND, stay awake, VPN, Tailscale). `amiga-bar strip` opens it with either option.
- Omarchy's own popups take the theme material too (0.7.0, `NativeMaterial.qml`): the status module finds the KeyboardPanel of every Omarchy widget it folds (network, Bluetooth, Tailscale, monitor …) and of Omarchy's panel widgets that stay in the native bar (audio, power, weather, world clock …; it walks the bar's scene a few times after loading) and hangs a FogPanel into it, as our own popups declare one – roll and theme shadow, the Lavur bloom (since 0.8.0 with the dried rim), the fog look. Omarchy's code is untouched; widgets keep their own (trusted) bar and services. A popup the search does not recognise keeps Omarchy's look; without fog or material nothing changes.
- `StatusScreen.qml`: the "screen behind the Workbench" with agents, nbtiles tests, AI quotas, phone, today & tomorrow, system & network; **Super+M** (Amiga-M) or Esc. `SysState.qml` polls only while one of them (or the drop-down) is open.
- Keybindings live in a managed block in `~/.config/hypr/bindings.lua` (`BEGIN/END Amiga Bar (managed)`).

## Companion: Amiga Island
The clock in the centre is the separate plugin `nerdibeard.amiga-island` (`~/src/omarchy-amiga-island`). It reads this plugin's `effects` and `font` options from shell.json and shows attention (blocked agents → requester), the Guru strip for failed units/crashes, Boing and copper effects. It stays a separate plugin: it has its own panel, IPC and settings entry, and merging would only re-plumb settings without user benefit; for a release both can live in one repository.

## Control Center
`ControlCenter.qml` (pure model in `ControlCenter.js`) replaces the old options
window: Quick · Configure, areas on the left (Quick, Amiga Bar, Amiga Island,
Card picker, Health), editor on the right, Ctrl+K search over settings and
their values, a Health chip. Edits are staged and confirmed the Amiga way:

- **Use** applies the staged changes live; the window stays open.
- **Save** applies what is still staged and closes.
- **Cancel** (button, close gadget, Esc once the search is closed, click
  outside, or any other close) restores the state from opening if Use applied
  something, then closes.

Bar options go out as one write (each write rebuilds the bar), island settings
through `omarchy-shell amiga-island set …`, the card picker through its
`menu-override.py`; one step at a time, each confirmed before the next. The
pixel font row is not staged: it may install the desktop profile and restart
the shell, so it applies at once and Cancel leaves it. Health only reports
live checks (base layout, font profile, AI usage refresh, notification
takeover marker, card picker override, last write, saved combinations). Hold
the depth gadget to look behind the window.

## Use
- Control Center: middle click on the Omarchy logo, Tools → Control Center, or
  `omarchy-shell amiga-bar options` (toggle) / `… cc quick|bar|island|cards|health`.
  `… state` includes `cc` (open, area, staged, used, health issues).
- `omarchy-shell amiga-bar preset heute|k1|k2|k3`, `… set <element> <variant>`, `… state`.
- Module IPC (tests/keybinds): `amiga-quota toggle|state`, `amiga-status group net|phone|system|all`, `amiga-status member <widget-id>`, `amiga-centre state`.
- `amiga-bar ask <payload>` is the menu shims' entry (an `omarchy-menu-select`/`-input` payload; answers `ok` when a drop-down took it).

## Develop
`OMARCHY_PATH=/path/to/omarchy ./dev-install.sh`. Custom modules and the `.pragma library` Presets.js are cached by the running shell: after code changes run `omarchy restart shell`, then re-apply a preset. Each preset change rebuilds the bar (widgets such as AI usage need 2–3 s). A changed `kinds` list in `manifest.json` (0.7.0 added `menu`) also needs the restart: the shell builds a plugin's scoped facade (and the app library in it) when it loads the plugin.

## Saved combinations

The Control Center's Amiga Bar area includes **My combinations**. Enter a name
and choose **Save / replace** (saves the options as shown, staged ones
included); select a saved name to stage it like a preset, or × to remove it.
Saving the same name replaces that combination. These are variant selections,
not snapshots of accounts or the entire desktop configuration. Data stays in
`~/.local/state/amiga-bar/presets.json` and survives shell restarts.
IPC: `omarchy-shell amiga-bar save "My focus"` / `... load "My focus"`.
The pixel font and event effects remain optional. Bar presets never change the system font or theme.

Folded widgets receive a presentation-only adapter, not access to another
plugin's services. Native Wi-Fi QR/speed-test and monitor OSD actions are
explicitly routed; member settings are stored in their `embeds` entry and
carried into the restoration baseline before the next preset switch.
`recaptureBase` refuses active Amiga layouts while a baseline exists: restore
**Today** first. If `base.json` is lost while Amiga modules are in the bar, the
baseline is rebuilt from them (each module turns back into the native widgets it
replaced, folded widgets keep their settings; order inside a group may differ)
and `state` reports it in `lastResult`.

## Verification

Run `node tests/regressions.cjs` with the companion island checkout next to this
repository. See [VERIFICATION.md](VERIFICATION.md) for the live checks and limits.
Everything remains local; no repository has been published or pushed.

## Pixel font and desktop profile

NerdWorkbench is Topaz on a whole-pixel 12×16 cell with pixel icons in the same
brick grid (see [FONTS.md](FONTS.md)). It is crisp at 16 and 32 px, so wherever
it is used every text size snaps to 16 px (32 px for display text).

Control Center → **Pixel font** chooses how far it reaches:

- **Theme font** — nothing changes.
- **Amiga moments** — menu strip, status screen, Workbench window title,
  requester, Guru strip and title line.
- **Bar, island & menus** — every Amiga Bar and Island text and icon.
- **Whole desktop** — additionally installs the desktop profile
  (`bin/system-font.py enable`):
  - fontconfig routes for the default families, only when they are the
    *requested first* family, so explicit fonts, icon fonts and emoji stay;
  - pixel rendering for NerdWorkbench (no antialiasing or hinting);
  - the Omarchy shell type scale set to 16/32 px (marked block in
    `~/.config/omarchy/shell.toml`);
  - GTK interface fonts at the point size that lands on 16 px with the current
    text-scaling-factor (previous values recorded and restored);
  - Ghostty and Kitty at 12 pt with 2 px row spacing in Ghostty (marked blocks);
  - Zen/Firefox chrome and the local OpenClaw UI (marked CSS blocks; websites
    keep their own fonts).

The option is saved only after the script succeeded; then Ghostty reloads and
the shell restarts. Choosing any other level removes the profile again: marked
blocks and the fonts are removed, GTK values restored (unless you changed them
meanwhile), and files that held only our block are deleted. Restart Zen and
reopen other apps to see browser/app changes. The Control Center warns when the
profile is only partly installed or out of step with the option.

IPC: `omarchy-shell amiga-bar set font theme|topaz|bar|desktop`; legacy
`… font amiga` (= desktop) and `… font normal` (= bar, profile removed).
Without a running shell:

```sh
python3 ~/.config/omarchy/plugins/nerdibeard.amiga-bar/bin/system-font.py status
python3 ~/.config/omarchy/plugins/nerdibeard.amiga-bar/bin/system-font.py restore
```

Each run keeps a backup of the touched files in
`~/.local/state/amiga-bar/font-profile-*/` (newest five). Config symlinks are
followed; unrelated rules and later edits outside our blocks are preserved.
Alacritty is not changed (its TOML cannot override a key from a later block).

Tests: `python3 tests/system_font.py` (fake HOME, private fontconfig, real
`fc-match`) and `node tests/regressions.cjs`.
Never overwrite a live installed TTF in place: use the helper's atomic installer.
