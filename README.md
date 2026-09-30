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
| Font | theme, topaz (menus, Workbench window, requester, Guru strip, title line) |
| Events | plain, amiga (Boing ball, copper progress; read by the island) |

Presets: `heute`, `k1` (pips · gauge · groups), `k2` (logo · VU · drawer · Topaz), `k3` (stack · on demand · deviations).

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
Topaz and event effects remain optional; no system font or theme is changed.

Folded widgets receive a presentation-only adapter, not access to another
plugin's services. Native Wi-Fi QR/speed-test and monitor OSD actions are
explicitly routed; member settings are stored in their `embeds` entry and
carried into the restoration baseline before the next preset switch.
`recaptureBase` refuses active Amiga layouts: restore **Today** first.

## Verification

Run `node tests/regressions.cjs` with the companion island checkout next to this
repository. See [VERIFICATION.md](VERIFICATION.md) for the live checks and limits.
Everything remains local; no repository has been published or pushed.
