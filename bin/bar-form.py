#!/usr/bin/env python3
"""Make the native Omarchy bar's own fill transparent for the A500 form.

The Amiga Bar draws the case (top face, wedge front, LED window, drive
slot) on a layer under the bar; the bar's widgets stay where they are.
Omarchy reads ~/.config/omarchy/shell.toml after the theme's shell.toml
(user keys win), so one managed block there sets [bar] background-alpha
to 0 — the bar text keeps the theme colour (unlike bar.transparent, which
picks a text colour from the wallpaper).

  bar-form.py enable    add the block (idempotent)
  bar-form.py disable   remove it (idempotent; the rest of the file stays)
  bar-form.py status    print {"form": "a500" | "full", "other_bar_keys": [...]}

Writes atomically and keeps the file mode. Never touches anything outside
the block; refuses to enable when the file already sets bar keys itself.
"""
import json
import os
import re
import sys
import tempfile
from pathlib import Path

PATH = Path(os.environ.get("OMARCHY_USER_SHELL_TOML", Path.home() / ".config/omarchy/shell.toml"))
BEGIN = "# >>> amiga-bar form (managed by nerdibeard.amiga-bar; removed with the form \"Full bar\")"
END = "# <<< amiga-bar form"
BLOCK = BEGIN + "\n[bar]\nbackground-alpha = 0.0\n" + END + "\n"


def read():
    try:
        return PATH.read_text()
    except FileNotFoundError:
        return ""


def strip(text):
    if BEGIN not in text:
        return text
    start = text.index(BEGIN)
    end = text.find(END, start)
    if end == -1:
        raise SystemExit(json.dumps({"error": "managed block has no end marker; file left unchanged"}))
    end += len(END)
    if text[end:end + 1] == "\n":
        end += 1
    out = text[:start] + text[end:]
    return out.rstrip("\n") + "\n" if out.strip() else ""


def other_bar_keys(text):
    """Keys the user sets under [bar] outside our block."""
    keys, section = [], None
    for line in strip(text).splitlines():
        s = line.strip()
        m = re.match(r"^\[([^\]]+)\]", s)
        if m:
            section = m.group(1).strip()
            continue
        if section == "bar" and s and not s.startswith("#") and "=" in s:
            keys.append(s.split("=", 1)[0].strip())
    return keys


def write(text):
    PATH.parent.mkdir(parents=True, exist_ok=True)
    mode = PATH.stat().st_mode & 0o777 if PATH.exists() else 0o600
    fd, tmp = tempfile.mkstemp(prefix=".shell-toml-amiga-bar.", dir=PATH.parent)
    with os.fdopen(fd, "w") as fh:
        fh.write(text)
    os.chmod(tmp, mode)
    os.replace(tmp, PATH)


def main():
    action = sys.argv[1] if len(sys.argv) > 1 else "status"
    text = read()
    if action == "status":
        print(json.dumps({"form": "a500" if BEGIN in text else "full", "other_bar_keys": other_bar_keys(text)}))
        return
    if action == "enable":
        if BEGIN in text:
            print(json.dumps({"form": "a500", "changed": False}))
            return
        others = other_bar_keys(text)
        if others:
            print(json.dumps({"error": "shell.toml already sets [bar] keys: " + ", ".join(others) + " — not changed"}))
            sys.exit(1)
        base = text.rstrip("\n")
        write((base + "\n\n" if base else "") + BLOCK)
        print(json.dumps({"form": "a500", "changed": True}))
        return
    if action == "disable":
        if BEGIN not in text:
            print(json.dumps({"form": "full", "changed": False}))
            return
        write(strip(text))
        print(json.dumps({"form": "full", "changed": True}))
        return
    print(json.dumps({"error": "usage: bar-form.py enable|disable|status"}))
    sys.exit(2)


if __name__ == "__main__":
    main()
