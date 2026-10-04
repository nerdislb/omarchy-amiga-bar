#!/bin/bash
# Undo setup/install.sh with the backup it made:
#   setup/revert.sh ~/.local/state/tusche-look/backup-<time>
# Puts back shell.json, the menu extension and the saved bar combinations as
# they were; restores the themes and plugin folders that existed before (an
# Amiga Bar / Island the install carried over included) and removes the ones
# the install added. What the carry-over undid outside the plugins (an Amiga
# fastfetch logo, the desktop font profile) stays undone.
# The repositories in ~/src stay (delete them yourself if you like). The boot
# screen is not touched: boot-logo.py restore --default puts Omarchy's back.
set -euo pipefail
backup="${1:-}"
[[ -n $backup && -d $backup && -f $backup/themes.installed ]] || { echo "usage: revert.sh <backup folder made by install.sh>" >&2; exit 2; }

echo "==> card picker menu entries"
mo="$HOME/src/omarchy-card-picker/bin/menu-override.py"
[[ -f $mo ]] && python3 "$mo" disable || true

echo "==> files"
while read -r f; do
  [[ -n $f ]] || continue
  mkdir -p "$(dirname "$HOME/$f")"
  cp -a "$backup/files/$f" "$HOME/$f" && echo "    restored $f"
done <"$backup/files.list"
for f in .local/state/tusche-bar/presets.json .local/state/tusche-bar/base.json; do
  grep -qx "$f" "$backup/files.list" || { rm -f "$HOME/$f" && echo "    removed $f (did not exist before)"; }
done

echo "==> themes"
while read -r t; do
  [[ -n $t ]] || continue
  if grep -qx "$t" "$backup/themes.list"; then
    rm -rf "$HOME/.config/omarchy/themes/$t" && cp -a "$backup/themes/$t" "$HOME/.config/omarchy/themes/$t" && echo "    restored $t"
  else
    rm -rf "$HOME/.config/omarchy/themes/$t" && echo "    removed $t"
  fi
done <"$backup/themes.installed"

echo "==> plugins"
# every folder that existed before comes back (the Amiga Bar / Island the
# install carried over and removed included); the ones it added go
while read -r id; do
  [[ -n $id ]] || continue
  rm -rf "$HOME/.config/omarchy/plugins/$id" && cp -a "$backup/plugins/$id" "$HOME/.config/omarchy/plugins/$id" && echo "    restored $id"
done <"$backup/plugins.list"
while read -r id; do
  [[ -n $id ]] || continue
  grep -qx "$id" "$backup/plugins.list" || { rm -rf "$HOME/.config/omarchy/plugins/$id" && echo "    removed $id"; }
done <"$backup/plugins.installed"

echo "==> restart the shell"
if pgrep -x quickshell >/dev/null; then omarchy restart shell || echo "    run: omarchy restart shell"; fi
echo "If the current theme was one of the four, pick another one: omarchy theme set <name>"
