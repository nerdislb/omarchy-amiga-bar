#!/bin/bash
# Copy the working tree into Omarchy's plugin folder (the shell hot-reloads
# plugin files). Re-run after every edit.
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
id="$(jq -r .id "$here/manifest.json")"
target="$HOME/.config/omarchy/plugins/$id"
mkdir -p "$target"
rsync -a --delete --exclude .git --exclude dev-install.sh --exclude ROADMAP.md --exclude README.md "$here/" "$target/"
omarchy plugin validate "$target"
echo "synced to $target"
