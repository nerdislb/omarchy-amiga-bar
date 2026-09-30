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
| AI quotas (`Quota.qml`) | today, gauge, vu, rings, ondemand |
| Right side (`Status.qml`) | today, groups, deviations, drawer (Workbench window) |
| Centre (`Centre.qml`) | today, calm (temperature at the weather glyph) |
| Font | theme, topaz (Workbench window title; more Amiga moments in stage C/D) |

Presets: `heute`, `k1` (pips · gauge · groups), `k2` (logo · VU · drawer · Topaz), `k3` (stack · on demand · deviations).

## Use
- Options: middle click on the Omarchy logo, or `omarchy-shell amiga-bar options`.
- `omarchy-shell amiga-bar preset heute|k1|k2|k3`, `… set <element> <variant>`, `… state`.
- Module IPC (tests/keybinds): `amiga-quota toggle|state`, `amiga-status group net|phone|system|all`, `amiga-status member <widget-id>`, `amiga-centre state`.

## Develop
`OMARCHY_PATH=/path/to/omarchy ./dev-install.sh`. Custom modules and the `.pragma library` Presets.js are cached by the running shell: after code changes run `omarchy restart shell`, then re-apply a preset. Each preset change rebuilds the bar (widgets such as AI usage need 2–3 s).
