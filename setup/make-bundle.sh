#!/bin/bash
# Offline bundle for a machine without GitHub access: the three repositories
# (Tusche Bar with themes and setup, Tusche Island, card picker) as clean
# clones of their release branches in one tar.gz. On the other machine:
#   tar xzf tusche-look-<date>.tar.gz && tusche-look/omarchy-tusche-bar/setup/install.sh
#   setup/make-bundle.sh [OUT.tar.gz]
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
src="$(dirname "$(dirname "$here")")"
out="${1:-$PWD/tusche-look-$(date +%Y-%m-%d).tar.gz}"
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
mkdir "$tmp/tusche-look"
for spec in omarchy-tusche-bar:master omarchy-tusche-island:main omarchy-card-picker:master; do
  repo="${spec%%:*}"; br="${spec##*:}"
  [[ -d "$src/$repo/.git" ]] || { echo "make-bundle: $src/$repo missing" >&2; exit 1; }
  git clone -q --branch "$br" "$src/$repo" "$tmp/tusche-look/$repo"
  git -C "$tmp/tusche-look/$repo" remote set-url origin "https://github.com/nerdislb/$repo.git"
  echo "$repo $(git -C "$tmp/tusche-look/$repo" log --oneline -1)"
done
tar czf "$out" -C "$tmp" tusche-look
echo "bundle: $out ($(du -h "$out" | cut -f1))"
