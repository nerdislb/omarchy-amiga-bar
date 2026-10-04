# Install the look on another machine

Brings the Nerdibeard desktop look of nerdbase2 to another Omarchy machine:

- the themes **Tusche, Papier, Tusche Lavur, Papier Lavur** (`themes/`, built
  by the Tusche & Papier design round's `build-themes.py`);
- the **Amiga Bar** and the **Amiga Island** with all their motion (logo
  arrival, seal tab, rolling cards, wet bloom, dried rim, system chip …);
- the **card picker** for themes and backgrounds (Style menu);
- the saved bar combinations (`paper` is loaded) and the island's settings
  (`look.json`), plus the Amiga logo in fastfetch.

## Needs

- **Omarchy:** a recent version, from early October 2026 or later. The script first checks the Amiga Bar's manifest against the local Omarchy and stops if it is refused.
- **Session:** run it as your user inside the desktop session (the shell must be running).
- **Tools:** `git`, `jq`, `python3`, `rsync`.
- **Access to the private repositories:** either GitHub (e.g. `gh auth login`) or the offline bundle.

## Install

With GitHub access:

```sh
git clone https://github.com/nerdislb/omarchy-amiga-bar.git ~/src/omarchy-amiga-bar
~/src/omarchy-amiga-bar/setup/install.sh --dry-run   # look first
~/src/omarchy-amiga-bar/setup/install.sh
```

Offline: on nerdbase2 run `setup/make-bundle.sh`. Copy the tar.gz across and run:

```sh
tar xzf nerdibeard-look-*.tar.gz
nerdibeard-look/omarchy-amiga-bar/setup/install.sh
```

### Options

| Option | Effect |
|---|---|
| `--theme papier\|tusche\|papier-lavur\|tusche-lavur` | Theme to switch to (default `papier`). |
| `--combination NAME` | Saved bar combination to load (default `paper`). |
| `--no-card-picker` | Leave the card picker out. |
| `--no-fastfetch` | Leave fastfetch's logo alone. |
| `--boot-logo` | Also put the seal on the boot screen (asks for sudo, rebuilds the initramfs). |
| `--src DIR` | Repository folder (default `~/src`). |
| `--dry-run` | Show every step and change nothing. |

## What it does

1. **Backup:** shell.json, the menu extension, the saved combinations, the four themes and the three plugin folders (if present), saved to `~/.local/state/nerdibeard-look/backup-<time>/`.
2. **Repositories:** clones them into `~/src` or fast-forwards them there (from beside this folder, else from GitHub). It stops on local changes.
3. **Plugins:** installs each with its `dev-install.sh`.
4. **Themes:** copies the four themes.
5. **Settings:**
   - merges the saved combinations;
   - puts the island in the place of Omarchy's clock (it is the clock), or merges the settings into its entry;
   - then enables the plugins.
6. **Extras:** the card picker's Style menu entries and the fastfetch logo.
7. **Apply:** restarts the shell, loads the bar combination and sets the theme.
8. **Boot screen** (optional): the seal.

Re-running it updates and reinstalls.

## Undo

```sh
~/src/omarchy-amiga-bar/setup/revert.sh ~/.local/state/nerdibeard-look/backup-<time>
```

It restores the backed-up files, themes and plugin folders and removes what the install added. The repositories in `~/src` and the boot screen stay; for the boot screen run `bin/boot-logo.py restore --default`.

## Not included

- Other plugins: OmaMail, WhatsApp, Flux, Buds, Drive and so on. Their bar widgets simply stay away.
- The workspace overview, the system font profile (off on nerdbase2), and anything with accounts or credentials.
