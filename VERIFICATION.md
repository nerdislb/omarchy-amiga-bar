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
