# Amiga Bar — roadmap

Private development first. No publishing until everything is complete and runs smoothly (owner decision, 2026-09-30).

Concept source: `~/.openclaw/workspace/output/amiga-bar-2026-09-30/` (gallery, ANALYSE.md, film). Island source: `~/src/omarchy-amiga-island` (merged here in stage A).

## Architecture
- One Omarchy plugin, `kinds` includes `bar`: a replacement bar that extends the native bar (`Native.Bar`, like `nerdibeard.fold-bar`), so every existing widget keeps working. Only bar plugins may rewrite `bar.layout` (`mutateShellConfig`), which presets need.
- Own parts ship inside the plugin (workspaces, AI quotas, status groups, island …).
- Options panel: presets + per-element variants + Amiga effects, saved as JSON; own combinations can be saved.
- Theme-neutral: colours always from the active theme; Amiga effects default on for the Amiga themes, optional otherwise.
- The previous bar stays as fallback (`bar.id` back to `omarchy.bar`; layout backup).

## Stages
- **A** — bar skeleton on Native.Bar, island merged, options panel, preset K1, workspace variants (pips, stack, logo, minimap, CLI, boing).
- **B** — AI variants (gauge, VU, rings, on demand), right side (groups, deviations only, drawer + Workbench icon window), weather in clock; presets K2, K3, "Heute+".
- **C** — attention: Guru box + requester from real herdr `blocked` state, Guru strip for service failures, DisplayBeep; Copper/Boing event language.
- **D** — Intuition menu strip (right button on empty bar), status screen overlay (depth gadget / Super+M), title-line variant, hardware strip variant.
- **E** — docs, screenshots, font licence check (Topaz, GPL-FE), release decision.

## Presets (from the concept film)
| Preset | Workspaces | AI | Centre | Right |
|---|---|---|---|---|
| Heute+ | today | today | island | today |
| K1 Aufgeräumt | pips | gauge | island + weather | groups |
| K2 Workbench | logo number | VU | island + weather | drawer |
| K3 Fokus | stack | on demand | island + weather | deviations only |
