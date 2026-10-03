# Private-build verification — 2026-09-30

Recovery and implementation: OpenClaw/Codex, GPT-6 Astra. Claude was quota-blocked;
no new Claude review, paid fallback or DeepSeek inference was used.

## Completed

- Existing eight-finding Codex review addressed: plain external text; protected
  baseline capture; member-specific popup/settings adapters; centralized focused
  monitor IPC; registered group click targets; floating attention/requester slots;
  separate system/user failure baselines; quoted diagnostic unit names.
- Added named local combinations, replace/load/remove controls and a scrollable
  options window. Corrupt/unreadable saved data is not overwritten.
- Fixed long Topaz menu labels overlapping metadata; bounded/scrolled menus.
- Regression checks: four preset builders, retained mail/WhatsApp widgets,
  embedded-settings round-trip, scope-specific startup failures, literal shell
  argument round-trip (backslashes, quotes, command-like text), focused monitor
  selection. Atomic layout writer checked with a disposable fixture: unrelated
  fields and mode 0600 preserved.
- All plugin QML files parse with Qt qmlformat; both manifests validate.
- Live switched Today/K1/K2/K3 plus 6 workspaces, 5 AI and 4 right-side variants;
  inspected bar captures, menu, status screen, options, Pixel group and native
  network popup. No new Amiga plugin QML errors during the final variant run.
- Named combination saved, survived a shell restart, then loaded successfully.
  Initial K3 restored; current combination also saved as “My focus”.
- Native Wayland keyboard injection confirmed menu navigation and Esc dismissal.
- Hyprland reports no configuration errors. No keybindings changed in recovery.

## Limits / remaining acceptance checks

- No pointer-injection provider was available: physical click / group-to-group
  switching and native popup settings edits were not end-to-end exercised.
- Focus routing tested with model fixtures; no second physical monitor test.
- Floating attention slots parse but were not rendered in a separate floating-mode
  live test. Real blocked-agent and actual crash events remain unobserved; no
  deliberate application crash, networking disconnect or agent approval was made.
- No global theme/reduced-motion switch or sustained soak test in this recovery.
- Preset changes still rebuild the bar; native AI usage may need 2–3 seconds.
- Right-click on empty native bar space cannot be intercepted; use the logo or
  Super+Alt+M. Island remains a separate companion. Publication remains withheld.

Local evidence and pre-change backups:
`~/.local/state/amiga-bar/codex-recovery-20260930/`.


## Optional system-font follow-up

Added an independent, default-off system Topaz selector with a restore action.
Two isolated tests pass: preservation/restoration of existing fontconfig rules
and real fc-match resolution for generic plus prior explicit families. QML
parses and installed option/status checked. The live desktop font was not
changed merely to test the option; visual system-wide acceptance remains open.


## Menu refresh selection fix

Owner reported Super+Alt+M jumping from the last tab/item back to the first.
The live menu rebuilt array-backed title/row delegates on its 4-second status
refresh; hover entry could steal keyboard selection. Stable count-based delegates
now bind their data separately. Pointer hover selection additionally requires a
change in window-relative pointer position, ignoring synthetic layout/creation
hover changes. Repeater.itemAt is used for anchors and keyboard scrolling.
Regression covers stationary global position with changed local coordinates,
then real movement. Live Tools → Options selection stayed tab 5/item 2 across
five refresh intervals (~21 seconds); Enter opened the intended options window.
QML parsing and journal check passed. No presets or user settings changed.

## NerdWorkbench profile (2026-09-30)

Supersedes the earlier classic Topaz follow-up. Four Python tests pass: XML
preservation/restoration, scoped CSS preservation and idempotence, atomic font
replacement with an existing reader, and isolated real fontconfig resolution.
Node regressions pass; edited QML parses. Live Amiga → Normal → Amiga succeeded:
Normal resolved to JetBrainsMono Nerd Font / Liberation Sans, removed owned
browser blocks and selected theme decoration without changing the other options.
Amiga resolved to NerdWorkbench UI / Mono, true Bold and Icons. Final options
window visually inspected; profile left active. Current layout stays CLI /
on-demand quotas / hardware / calm centre / Amiga effects.

Zen stylesheets are installed, not live-verified: the running browser has not
been restarted. Arbitrary website typography is intentionally not overridden.
No universal application or long-running stability claim is made.

During development, quickshell PID 806550 crashed at 18:28:02 CEST. Coredump
metadata places the fault in FreeType FT_Get_Char_Index / Qt text shaping.
Timing coincides with an in-place copy of a loaded TTF; that is the likely
trigger, not a proven source-level root cause. The installer now uses atomic
replacement and skips unchanged fonts; an old-reader regression passes. No
further coredumps were found after 18:29 through final profile testing.
Evidence: local font-profile backups and font-family-20260930 state directory.

## Pixel font everywhere, one icon system, review fixes (2026-09-30, Claude Opus 5.5)

Review of the NerdWorkbench profile found: fontconfig rules used `qual="any"`
with strong prepend, so explicit families (Arial, Inter, Symbols Nerd Font,
Font Awesome, unknown names) also became NerdWorkbench, and Topaz's own
private-use glyphs masked Font Awesome icons; the ×1.5/×1.75 stretch put
edges on half pixels (soft, uneven text); only 12 pixel icons existed.

- Fonts rebuilt: one family, NerdWorkbench Mono, on a whole-pixel 12×16 cell;
  rendering a sample at 16 px with antialiasing yields exactly two grey levels.
  10,370 icons in the same brick grid (Nerd ranges + Omarchy glyphs, pixelated
  with an offset search; 91 hand-drawn/generated). Review sheets of the ~230
  icons used by the bar, island and native widgets were inspected.
- Desktop profile rewritten (`qual="first"` routes, pixel rendering, shell
  tokens 16/32 px, GTK at 16 px, Ghostty/Kitty, CSS). 7 Python tests pass:
  scoped resolution with real `fc-match` (Arial, Helvetica, Inter, DejaVu Sans,
  Font Awesome, emoji and unknown names untouched; Symbols Nerd Font → Icons;
  NerdWorkbench not antialiased), marked-block idempotence, atomic font
  replacement with an old reader, and fake-HOME end-to-end enable → enable →
  restore (byte-identical files, GTK values restored, fonts removed, only-ours
  files deleted, user changes kept, backups rotated). Node regressions pass,
  incl. base reconstruction for every preset and desktop-font protection.
- Live: legacy partial profile detected as `partial`; `set font desktop`
  installed all seven parts, then saved the option and restarted the shell.
  `fc-match`: generics, JetBrainsMono, Inconsolata, Adwaita → NerdWorkbench
  Mono (aa=False); Symbols Nerd Font, omarchy → Icons; Arial, Inter, emoji
  unchanged. Live round trip desktop → bar → desktop: fontconfig matched the
  pre-GPT original, shell.toml/Ghostty/Kitty byte-identical to the backup,
  GPT-created userContent.css removed, GTK back to Adwaita, fonts removed.
  Level switches theme/topaz/bar ran without QML warnings (after fixing a
  transitional binding loop in the LED).
- Screenshots inspected: bar, options window, menu strip, status screen,
  island (activity, calendar), attention segment, Guru strip (`guruTest`),
  native audio panel and Omarchy menu, and a Ghostty window at 12 pt.
- Also fixed: embedded widgets are no longer rebuilt (popups closed) on
  settings edits; LEDs and DF0 are registered bar click targets; the Guru strip
  renders systemd names as plain text; failed-unit scans count only on exit 0;
  the font option is saved only after the profile script succeeded; lost
  `base.json` is rebuilt from the modules instead of dead-ending.

Not verified: Zen chrome/userContent (browser not restarted), Kitty (not
running), GTK apps visually, a real (non-demo) blocked agent and a real failed
unit through the new exit-code path.

## Stale AI limits (2026-09-30, Claude Opus 5.5)

Owner report: the bar showed "Claude 5h 100%". `claude.json`/`codex.json` were
last written at 16:26 CEST; the 5-hour window had reset at 18:09. Cause: the
collectors run from `omarchy.agents` (and the AI usage widget) only while
they are in the bar, and the `ondemand` variant folds both away. The engine
now runs the collectors while they are folded, and expired limits read as 0 %.
Live after restart: engine `usage.folded=true`, collector ran at once;
Claude 5 h 56 % (reset 23:39), weekly 10 %, Codex weekly 28 %; the on-demand
quota hid itself (< 75 %). Regression covers expired vs. future resets.

## Amiga logo (2026-09-30, Claude Opus 5.5)

New option Logo: omarchy · amiga (rainbow double tick after the Commodore
Amiga logo; front tick in theme red/orange/yellow/green/blue, rear tick darker
instead of the original's outline) · boing (Boing ball). 13×8 and 10×8 bricks
of the pixel font grid (1.5 × 2 px, whole-pixel columns), 16 px tall. With
native workspaces only omarchy.menu is replaced (variant "none"). K2 uses the
Amiga tick. Regressions pass, incl. a new test for the menu-only module; it
also caught reconstructBase adding omarchy.agents to layouts that never had
it (fixed: only when a status/quota module could have folded it). Live: both
logos captured at 1:1 and 4× on the dark theme, no QML warnings; left on amiga.

## fastfetch Amiga logo (2026-09-30, Claude Opus 5.5)

`bin/fastfetch-logo.py`: fake-HOME test (enable twice, restore) keeps
padding and other modules and restores the config byte-identically. Live:
config backed up, enabled, JSON validated; a Ghostty window running plain
`fastfetch` showed the tick and AMIGA crisp in NerdWorkbench beside the info;
the theme-set hook ran without error.


## Nested drop-down menu (2026-10-03, Claude Opus 5.5, 0.7.0-local.1)

Owner request: picks in the drop-down logo menu must never end in the centred
Omarchy menu. Apps, fonts and power profiles now open as levels inside the
drop-down; questions of the actions it runs (`omarchy-menu-select` /
`omarchy-menu-input`) are answered inside it via `bin/menu-shim` and the
`amiga-bar ask` IPC (see README › Logo menu).

Checked without touching the live session (no shell, IPC or install):

- Omarchy's shell code read and run in isolation (`tests/regressions.cjs`):
  with `"menu"` added to `kinds` the plugin still loads as the same
  keep-loaded panel (`computePanelEntries` picks `panel`, same entry point),
  it is not a bar-widget panel, and only its capability profile changes
  (`own-service|no-bar|menu`), which is what hands it `shell.appLibrary`.
  `entryPoints.menu` (Engine.qml) exists because `omarchy plugin validate`
  requires one per kind; the shell never loads it for a plugin that is also a
  panel. `omarchy-plugin-validate` passes on the tree.
- The copied providers equal the native menu's (`fonts`, `power-profiles`:
  script, icon, volatile, action); `vendor/MenuModel.js` is still upstream's.
- Question rows parse like the native dmenu (glyph · label · subtext, answer
  `label` or `label\tsubtext`); list filtering by label and subtext; the
  engine's routing (launching drop-down by token, open one, last screen,
  focused screen, first; refuses invalid payloads and relative paths).
- The drop-down's own write commands, run as the QML runs them: answer then
  done file; cancel = done file only; nothing once the asker has gone;
  shell-looking answers stay literal.
- Asking-action detection against the live menu definition (read only):
  14 rows in ~25 ms — Keybindings, Tmux, Herdr, Timezone, the four plugin
  rows, Remove › TUI/Theme/Web App, Transcode, RetroArch launcher, webcam
  recording (the latter exempt from waiting: captures must not see the menu).
- The tracked launch (`setsid -f -w`): the waiter ends with the action, and
  the action keeps running (shims first on PATH, token set) after its waiter
  is killed.
- Shims end to end in a temp dir with fake `omarchy-shell`s (answering,
  failing, refusing) and fake originals: answers, cancels, payload fields
  (width, maxHeight, token), options from arguments and from stdin, exit
  codes, no temp files left, the fallback with identical arguments and stdin,
  no recursion with the shim directory on PATH three ways. `bash -n` clean.
- `qmllint` on the four changed QML files: exit 0; only the known import /
  unqualified-access / QProcess::ExitStatus warnings of this repository.

Live test (owner/lead): `./dev-install.sh`, then `omarchy restart shell`
(the new manifest kind takes effect on load); `omarchy-shell amiga-bar state
| jq .ask` should show `"appLibrary": true`. Then, from the drop-down:
Apps (icons, typing filters, Enter launches), Style › Font (✓, pick),
Learn › Keybindings (waiting row, then the 800 px list; a pick runs the
binding), Update › Timezone (type to filter, Esc cancels quietly),
Setup › Plugins › Enable/Disable Plugin, Remove › TUI. A question with the
drop-down closed opens it at the question:
`PATH=~/.config/omarchy/plugins/nerdibeard.amiga-bar/bin/menu-shim:$PATH omarchy-menu-select Test a b`
in any terminal prints the pick (exit 1 on Esc); with `menu: strip` the
same command gets the centred menu.

Not verified live: rendering (icons, widths, the ListView with the fog,
roll and bloom looks), focus when a question opens the drop-down by itself,
multi-monitor routing, and the 3 s waiting limit with slow scripts.
