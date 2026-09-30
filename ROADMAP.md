# Amiga Bar — roadmap

Private development first. No publishing until everything is complete and runs smoothly (owner decision, 2026-09-30).

Concept source: `~/.openclaw/workspace/output/amiga-bar-2026-09-30/` (gallery, ANALYSE.md, film). Island source: `~/src/omarchy-amiga-island` (merged here in stage A).

## Architecture
- One Omarchy panel plugin next to the **native** bar (see README for why not a replacement bar). Presets rewrite `bar.layout` via `bin/apply-layout.py`.
- Own parts ship inside the plugin (workspaces, AI quotas, status groups, island …).
- Options panel: presets + per-element variants + Amiga effects, saved as JSON; own combinations can be saved.
- Theme-neutral: colours always from the active theme; Amiga effects default on for the Amiga themes, optional otherwise.
- The previous bar stays as fallback (`bar.id` back to `omarchy.bar`; layout backup).

## Stages
- **A** ✓ — options, presets, workspace variants (pips, stack, logo, minimap, CLI, boing). Island merge moved to E.
- **B** ✓ — AI variants, right side (groups, deviations, drawer + Workbench window) with embedded native popups, temperature at the weather, Topaz option; presets K1–K3 complete.
- **C** ✓ — (in the island) blocked agents → Guru-style orange segment + requester (open/snooze, never auto-approve), Guru strip for failed user/system units and new core dumps, DisplayBeep, Boing/Copper behind the "effects" option. Real herdr `blocked` not yet observed live (tested with a demo agent).
- **D** ✓ — Intuition menu strip (right click on the Omarchy logo or Super+Alt+M; Topaz optional), status screen (Super+M, "Amiga-M"), title-line quota variant (hires Topaz), A500 hardware strip (CPU/RAM VU, POWER/DRIVE LEDs, DF0: USB phone). UI strings in English (owner rule: desktop UI English).
- **E** ✓ (except release) — docs, font licence notice (Topaz: GPL with font exception, design © Amiga Inc.; `assets/fonts/FONTS.md`), independent Codex review, full live test of all presets. Island stays a separate plugin (see README); the release decision is the owner's.

## Not possible / deliberately left out
- Right *mouse button held on empty bar space*: only bar plugins see those events, and a replacement bar breaks service-backed widgets. The menu opens from the logo or Super+Alt+M instead.
- Hiding native widgets without removing them: needs a bar plugin; folded widgets are mounted inside our Status module instead.
- Weather and world clocks stay native: embedded, their popups position themselves through the bar's centre section and land at the left edge.
- Approving agents from the bar: the requester only opens/snoozes; approval stays in the agent.

## Presets (from the concept film)
| Preset | Workspaces | AI | Centre | Right |
|---|---|---|---|---|
| Heute+ | today | today | island | today |
| K1 Aufgeräumt | pips | gauge | island + weather | groups |
| K2 Workbench | logo number | VU | island + weather | drawer |
| K3 Fokus | stack | on demand | island + weather | deviations only |
