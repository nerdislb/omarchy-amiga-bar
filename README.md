# Amiga Bar (private build)

The native Omarchy bar with presets and compact Amiga-style modules. Extends `qs.plugins.bar` (`Native.Bar`), so every existing widget, drag-reorder, popouts and theming keep working. See `ROADMAP.md` for stages A–E.

## Use
- Options: middle click on the Omarchy logo, or `omarchy-shell amiga-bar options` (popup under the clock).
- Presets: `omarchy-shell amiga-bar preset heute|k1|k2|k3`.
- One element: `omarchy-shell amiga-bar set workspaces pips|stack|logo|minimap|cli|boing|today`.
- State: `omarchy-shell amiga-bar state`.

Your own layout is saved to `~/.local/state/amiga-bar/base.json` before the first preset; `heute` restores it. Choices are stored in `shell.json` under `bar.amiga`.

## Install / develop
`OMARCHY_PATH=/path/to/omarchy ./dev-install.sh`, then select the bar (`bar.id = "nerdibeard.amiga-bar"`). Back to the stock bar: `omarchy plugin disable nerdibeard.amiga-bar` (removes `bar.id`; `bar.layout` is kept).

## Modules
Own modules are loaded as custom QML modules (`{ "id": "amiga.*", "source": ".../modules/X.qml" }`), because one plugin can register only one bar widget.
- `modules/Workspaces.qml` — variants `pips`, `stack`, `logo`, `minimap`, `cli`, `boing`; includes the Omarchy menu logo (left: menu, right: terminal); mouse wheel steps workspaces.
