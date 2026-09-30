# Amiga Bar (private build)

Presets and compact Amiga-style modules for the **native** Omarchy bar. See `ROADMAP.md` for stages A–E.

## Architecture
- `Engine.qml` — keep-loaded panel plugin (`nerdibeard.amiga-bar`): options window, presets, IPC. It writes `bar.layout` through `bin/apply-layout.py` (atomic, keeps shell.json's 0600 mode). The bar itself stays `omarchy.bar`.
- Why not a replacement bar: under a plugin bar, Omarchy hands third-party widgets a service-less shell facade (security boundary), so OmaMail, WhatsApp and Flux lose their own services. Tried in stage A, reverted.
- Own parts are custom QML modules in the layout (`{ "id": "amiga.x", "source": "<plugin>/modules/X.qml", ... }`); one plugin can register only one bar widget.
- `modules/Status.qml` mounts the widgets it folds away invisibly (`embeds`: id → original settings), so their native popups (Wi-Fi, Bluetooth, VPN, Tailscale, monitor, drive, radar, plugins, buds, system monitor) still open from our groups/drawer. Flux, OmaMail and WhatsApp are not embedded (they need their own services); Flux is read via `flux-cli` and opened as its window. Weather and world clocks stay native (their popups position via the centre section).
- The user's layout is captured once in `~/.local/state/amiga-bar/base.json`; "Heute" restores it. Options live in this plugin's `plugins[]` entry.

## Elements and variants
| Element | Variants |
|---|---|
| Workspaces (`Workspaces.qml`, incl. Omarchy logo) | today, pips, stack, logo, minimap, cli, boing |
| AI quotas (`Quota.qml`) | today, gauge, vu, rings, ondemand, title (Workbench title line) |
| Right side (`Status.qml`) | today, groups, deviations, drawer (Workbench window), hardware (A500 strip) |
| Centre (`Centre.qml`) | today, calm (temperature at the weather glyph) |
| Pixel font (NerdWorkbench) | theme · topaz = Amiga moments (menu strip, status screen, Workbench window title, requester, Guru strip, title line) · bar = all Amiga Bar and Island text and icons · desktop = bar + the reversible desktop profile |
| Events | plain, amiga (Boing ball, copper progress; read by the island) |

Presets: `heute`, `k1` (pips · gauge · groups), `k2` (logo · VU · drawer · pixel font for bar & island), `k3` (stack · on demand · deviations).
Presets and saved combinations never switch the desktop font profile: while it is on they keep `desktop`, otherwise a saved `desktop` loads as `bar`.

AI usage records (`~/.local/state/omarchy/agents/usage`) are refreshed by
`omarchy.agents` only while it sits in the bar. When a variant folds the AI
widgets away, the engine runs `omarchy-agent-usage-update` itself with that
widget's interval and disabled providers (retrying advised limits after 30 s),
and fetches limits when the quota popup or status screen opens. A limit past
its reset time always counts as reset (0 %), in the bar, status screen and
island, even before a fresh record arrives.

## Menu strip and status screen
- `IntuitionMenu.qml`: Omarchy · Agents · System · Network · Phone · Tools, opened by right click on the Omarchy logo or **Super+Alt+M**; arrows/Enter/Esc; toggles show ✓ (DND, stay awake, VPN, Tailscale).
- `StatusScreen.qml`: the "screen behind the Workbench" with agents, nbtiles tests, AI quotas, phone, today & tomorrow, system & network; **Super+M** (Amiga-M) or Esc. `SysState.qml` polls only while one of them is open.
- Keybindings live in a managed block in `~/.config/hypr/bindings.lua` (`BEGIN/END Amiga Bar (managed)`).

## Companion: Amiga Island
The clock in the centre is the separate plugin `nerdibeard.amiga-island` (`~/src/omarchy-amiga-island`). It reads this plugin's `effects` and `font` options from shell.json and shows attention (blocked agents → requester), the Guru strip for failed units/crashes, Boing and copper effects. It stays a separate plugin: it has its own panel, IPC and settings entry, and merging would only re-plumb settings without user benefit; for a release both can live in one repository.

## Use
- Options: middle click on the Omarchy logo, or `omarchy-shell amiga-bar options`.
- `omarchy-shell amiga-bar preset heute|k1|k2|k3`, `… set <element> <variant>`, `… state`.
- Module IPC (tests/keybinds): `amiga-quota toggle|state`, `amiga-status group net|phone|system|all`, `amiga-status member <widget-id>`, `amiga-centre state`.

## Develop
`OMARCHY_PATH=/path/to/omarchy ./dev-install.sh`. Custom modules and the `.pragma library` Presets.js are cached by the running shell: after code changes run `omarchy restart shell`, then re-apply a preset. Each preset change rebuilds the bar (widgets such as AI usage need 2–3 s).

## Saved combinations

The options window includes **My combinations**. Enter a name and choose
**Save / replace**; select a saved name to load it, or × to remove it.
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

Options → **Pixel font** chooses how far it reaches:

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
reopen other apps to see browser/app changes. The options window warns when the
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
