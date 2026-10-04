#!/bin/bash
# Install the Nerdibeard look on this machine: the Tusche & Papier themes, the
# Amiga Bar and the Amiga Island with all their motion (logo arrival, seal tab,
# rolling cards, wet bloom, dried rim, system chip ...), the card picker, the
# saved bar combinations and the island settings from setup/look.json.
#
#   setup/install.sh [options]
#     --theme NAME         theme to switch to (default from look.json: papier)
#     --combination NAME   saved bar combination to load (default: paper)
#     --no-card-picker     leave the card picker out
#     --no-fastfetch       leave fastfetch's logo alone
#     --boot-logo          also put the seal on the boot screen (asks for sudo)
#     --src DIR            where the repositories live (default ~/src)
#     --dry-run            show what would happen, change nothing
#
# Run it as your user inside the desktop session. It is re-runnable (updates
# the repositories fast-forward and reinstalls). Everything it changes is
# backed up first under ~/.local/state/nerdibeard-look/backup-<time>/;
# setup/revert.sh <that folder> puts it back.
# Repositories come from beside this one (offline bundle) or from GitHub.
set -euo pipefail

here="$(cd "$(dirname "$0")" && pwd)"
bar_repo="$(dirname "$here")"
look="$here/look.json"
SRC="$HOME/src"
theme=""
combo=""
card_picker=true
fastfetch=true
boot_logo=false
dry=false

while (( $# )); do
  case "$1" in
    --theme) theme="$2"; shift 2 ;;
    --combination) combo="$2"; shift 2 ;;
    --no-card-picker) card_picker=false; shift ;;
    --no-fastfetch) fastfetch=false; shift ;;
    --boot-logo) boot_logo=true; shift ;;
    --src) SRC="$2"; shift 2 ;;
    --dry-run) dry=true; shift ;;
    -h|--help) sed -n '2,23p' "$0" | sed 's/^# \{0,1\}//'; exit 0 ;;
    *) echo "install: unknown option $1 (see --help)" >&2; exit 2 ;;
  esac
done

theme="${theme:-$(jq -r '.theme // "papier"' "$look")}"
combo="${combo:-$(jq -r '.barCombination // "paper"' "$look")}"
themes=(tusche papier tusche-lavur papier-lavur)
repos=(omarchy-amiga-bar omarchy-amiga-island)
$card_picker && repos+=(omarchy-card-picker)

step() { printf '\n==> %s\n' "$*"; }
note() { printf '    %s\n' "$*"; }
run() { if $dry; then printf '    [dry-run] %s\n' "$*"; else "$@"; fi; }
die() { printf 'install: %s\n' "$*" >&2; exit 1; }

plugin_id() { case "$1" in omarchy-amiga-bar) echo nerdibeard.amiga-bar ;; omarchy-amiga-island) echo nerdibeard.amiga-island ;; omarchy-card-picker) echo nerdibeard.card-picker ;; esac; }
branch_of() { case "$1" in omarchy-amiga-island) echo main ;; *) echo master ;; esac; }

# ---------------------------------------------------------------- 0 · preflight
step "Preflight"
for cmd in omarchy omarchy-shell git jq python3 rsync; do
  command -v "$cmd" >/dev/null || die "$cmd is missing"
done
[[ $theme =~ ^(tusche|papier|tusche-lavur|papier-lavur)$ ]] || die "--theme must be one of: ${themes[*]}"
jq -e --arg c "$combo" '.barCombinations | any(.name == $c)' "$look" >/dev/null || die "no saved combination named '$combo' in look.json"
note "user $USER · Omarchy at ${OMARCHY_PATH:-?} · $(omarchy version 2>/dev/null | head -1 || echo 'version unknown')"
pgrep -x quickshell >/dev/null || $dry || die "run this inside the desktop session (the Omarchy shell is not running)"
# the plugin manifests must pass this machine's Omarchy schema (an older Omarchy would refuse them)
omarchy plugin validate "$bar_repo" >/dev/null || die "this Omarchy rejects the Amiga Bar's manifest – update Omarchy first (the build is from early October 2026)"
[[ -f "${OMARCHY_PATH:-/nonexistent}/shell/Ui/KeyboardPanel.qml" || -f /usr/share/omarchy/shell/Ui/KeyboardPanel.qml ]] ||
  note "warning: Omarchy's KeyboardPanel was not found where expected – the drop-down menu needs it"

# ---------------------------------------------------------------- 1 · backup
stamp="$(date +%Y%m%d-%H%M%S)"
backup="$HOME/.local/state/nerdibeard-look/backup-$stamp"
step "Backup -> $backup"
if ! $dry; then
  mkdir -p "$backup/themes" "$backup/plugins"
  for f in .config/omarchy/shell.json .config/omarchy/extensions/omarchy-menu.jsonc .local/state/amiga-bar/presets.json; do
    if [[ -e "$HOME/$f" ]]; then mkdir -p "$backup/files/$(dirname "$f")"; cp -a "$HOME/$f" "$backup/files/$f"; echo "$f" >>"$backup/files.list"; fi
  done
  for t in "${themes[@]}"; do
    [[ -d "$HOME/.config/omarchy/themes/$t" ]] && cp -a "$HOME/.config/omarchy/themes/$t" "$backup/themes/" && echo "$t" >>"$backup/themes.list"
  done
  for r in "${repos[@]}"; do
    id="$(plugin_id "$r")"
    [[ -d "$HOME/.config/omarchy/plugins/$id" ]] && cp -a "$HOME/.config/omarchy/plugins/$id" "$backup/plugins/" && echo "$id" >>"$backup/plugins.list"
  done
  printf '%s\n' "${themes[@]}" >"$backup/themes.installed"
  for r in "${repos[@]}"; do plugin_id "$r"; done >"$backup/plugins.installed"
  touch "$backup/themes.list" "$backup/plugins.list" "$backup/files.list"
fi
note "shell.json, menu extension, saved combinations, the four themes and the plugin folders (if present)"

# ---------------------------------------------------------------- 2 · repositories
step "Repositories in $SRC"
run mkdir -p "$SRC"
for r in "${repos[@]}"; do
  dest="$SRC/$r"
  br="$(branch_of "$r")"
  if [[ $r == omarchy-amiga-bar ]]; then src="$bar_repo"
  elif [[ -d "$(dirname "$bar_repo")/$r/.git" ]]; then src="$(dirname "$bar_repo")/$r"
  else src="https://github.com/nerdislb/$r.git"; fi
  # in place only when both are existing folders and the same one (two missing paths are not "the same")
  if [[ -d $dest && -d $src && $(cd "$dest" && pwd -P) == $(cd "$src" && pwd -P) ]]; then
    if [[ $r == omarchy-amiga-bar ]]; then
      note "$r: in place ($dest) – to update it, git pull there before running this"
    else
      [[ -z $(git -C "$dest" status --porcelain) ]] || die "$dest has local changes – commit or stash them first"
      note "$r: in place ($dest), pull $br from origin"
      run git -C "$dest" checkout -q "$br"
      if ! $dry; then git -C "$dest" pull -q --ff-only origin "$br" || note "$r: pull failed (offline or no access?) – kept as it is"; fi
    fi
  elif [[ -d "$dest/.git" ]]; then
    [[ -z $(git -C "$dest" status --porcelain) ]] || die "$dest has local changes – commit or stash them first"
    note "$r: update $dest from $src ($br, fast-forward)"
    if $dry; then
      note "[dry-run] git -C $dest fetch $src $br, then $br fast-forward (or create $br)"
    else
      git -C "$dest" fetch -q "$src" "$br"
      if git -C "$dest" rev-parse -q --verify HEAD >/dev/null && ! git -C "$dest" merge-base HEAD FETCH_HEAD >/dev/null; then
        die "$dest is a different repository (no shared history) – move it aside (mv $dest $dest.old) or use --src DIR, then run this again"
      elif git -C "$dest" show-ref --verify --quiet "refs/heads/$br"; then
        git -C "$dest" checkout -q "$br"
        git -C "$dest" merge -q --ff-only FETCH_HEAD ||
          die "$dest: its $br has commits of its own – merge them by hand, or move the folder aside (mv $dest $dest.old) and run this again"
      else
        # an older or partial clone without this branch: start it at the fetched one (other branches stay)
        note "$r: $dest has no branch $br yet – creating it"
        git -C "$dest" checkout -q -b "$br" FETCH_HEAD
      fi
    fi
  else
    note "$r: clone $src -> $dest ($br)"
    run git clone -q --branch "$br" "$src" "$dest"
    run git -C "$dest" remote set-url origin "https://github.com/nerdislb/$r.git"
  fi
done

# ---------------------------------------------------------------- 3 · plugin files
step "Plugins: files"
for r in "${repos[@]}"; do
  note "$(plugin_id "$r"): install from $SRC/$r"
  if $dry; then note "[dry-run] $SRC/$r/dev-install.sh"; else (cd "$SRC/$r" && ./dev-install.sh >/dev/null); fi
done
run omarchy-shell shell rescanPlugins

# ---------------------------------------------------------------- 4 · themes
step "Themes: ${themes[*]}"
run mkdir -p "$HOME/.config/omarchy/themes"
for t in "${themes[@]}"; do
  run rsync -a --delete "$bar_repo/themes/$t/" "$HOME/.config/omarchy/themes/$t/"
done

# ---------------------------------------------------------------- 5 · settings, then enable
# The island's entry goes in first (in the clock's place): enabling a bar widget
# that has no entry yet would put it at its default spot instead.
step "Settings from look.json (saved bar combinations, island)"
if $dry; then python3 "$here/apply-settings.py" --look "$look" --dry-run; else python3 "$here/apply-settings.py" --look "$look"; sleep 1.5; fi
step "Plugins: enable"
for r in "${repos[@]}"; do
  id="$(plugin_id "$r")"
  if $dry; then note "[dry-run] omarchy plugin enable $id"; continue; fi
  out=""
  for _ in 1 2 3 4 5; do
    out="$(omarchy plugin enable "$id" 2>&1)" && break
    sleep 1; omarchy-shell shell rescanPlugins >/dev/null 2>&1 || true
  done
  note "$id: $out"
done

# ---------------------------------------------------------------- 6 · card picker menu, fastfetch logo
if $card_picker; then
  step "Card picker in the Style menu (Theme, Background)"
  run python3 "$SRC/omarchy-card-picker/bin/menu-override.py" enable
fi
if $fastfetch; then
  step "fastfetch logo"
  if [[ -f "$HOME/.config/fastfetch/config.jsonc" ]]; then
    run python3 "$HOME/.config/omarchy/plugins/nerdibeard.amiga-bar/bin/fastfetch-logo.py" enable
  else
    note "no ~/.config/fastfetch/config.jsonc – skipped"
  fi
fi

# ---------------------------------------------------------------- 7 · restart, bar, theme
step "Restart the shell, load the bar combination '$combo', theme $theme"
if ! $dry; then
  if pgrep -x quickshell >/dev/null; then
    omarchy restart shell || die "the shell did not restart (locked session?) – unlock and run: omarchy restart shell"
  fi
  ok=false
  for _ in $(seq 1 60); do
    if omarchy-shell amiga-bar state >/dev/null 2>&1; then ok=true; break; fi
    sleep 0.5
  done
  $ok || die "the Amiga Bar does not answer – check: omarchy plugin list"
  result="$(omarchy-shell amiga-bar load "$combo" 2>&1 || true)"
  note "bar: $result"
  for _ in $(seq 1 20); do
    omarchy-shell amiga-bar state 2>/dev/null | jq -e --arg c "$combo" --slurpfile l "$look" \
      '.options.logo == ($l[0].barCombinations[] | select(.name == $c) | .options.logo)' >/dev/null && break
    sleep 0.5
  done
  omarchy theme set "$theme" >/dev/null 2>&1 || note "theme: run 'omarchy theme set $theme' yourself"
else
  note "[dry-run] omarchy restart shell; omarchy-shell amiga-bar load $combo; omarchy theme set $theme"
fi

# ---------------------------------------------------------------- 8 · boot screen (optional)
if $boot_logo; then
  step "Boot screen: the seal in $theme's colours (sudo)"
  run python3 "$HOME/.config/omarchy/plugins/nerdibeard.amiga-bar/bin/boot-logo.py" set nerdibeard --theme "$theme"
fi

step "Done"
$dry && note "dry run – nothing was changed" || note "backup: $backup  ·  undo: $SRC/omarchy-amiga-bar/setup/revert.sh $backup"
note "switch logo/bar: middle click on the logo (Control Center) · themes and backgrounds: Style menu (card picker)"
