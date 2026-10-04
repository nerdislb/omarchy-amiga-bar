#!/bin/bash
# Offline bundle for a machine without GitHub access: the three repositories
# (Amiga Bar with themes and setup, Amiga Island, card picker) as clean clones
# of their release branches in one tar.gz. On the other machine:
#   tar xzf nerdibeard-look-<date>.tar.gz && nerdibeard-look/omarchy-amiga-bar/setup/install.sh
#   setup/make-bundle.sh [OUT.tar.gz]
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
src="$(dirname "$(dirname "$here")")"
out="${1:-$PWD/nerdibeard-look-$(date +%Y-%m-%d).tar.gz}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/nerdibeard-look"
for spec in omarchy-amiga-bar:master omarchy-amiga-island:main omarchy-card-picker:master; do
  repo="${spec%%:*}"; br="${spec##*:}"
  [[ -d "$src/$repo/.git" ]] || { echo "make-bundle: $src/$repo missing" >&2; exit 1; }
  git clone -q --branch "$br" "$src/$repo" "$tmp/nerdibeard-look/$repo"
  git -C "$tmp/nerdibeard-look/$repo" remote set-url origin "https://github.com/nerdislb/$repo.git"
  echo "$repo $(git -C "$tmp/nerdibeard-look/$repo" log --oneline -1)"
done
tar czf "$out" -C "$tmp" nerdibeard-look
echo "bundle: $out ($(du -h "$out" | cut -f1))"
