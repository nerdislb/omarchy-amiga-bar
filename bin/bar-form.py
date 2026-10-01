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
import tomllib
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
    # Keys the user added right after the block belong to its [bar] table:
    # keep the header for them.
    rest = text[end:]
    tail = []
    for line in rest.splitlines():
        if re.match(r"^\s*\[", line):
            break
        tail.append(line)
    keep = "[bar]\n" if any(l.strip() and not l.strip().startswith("#") for l in tail) else ""
    out = text[:start] + keep + rest
    return out.rstrip("\n") + "\n" if out.strip() else ""


def other_bar_keys(text):
    """How the file outside our block already defines the bar table (any
    of these makes a second [bar] table invalid TOML)."""
    rest = strip(text)
    try:
        doc = tomllib.loads(rest)
    except tomllib.TOMLDecodeError:
        return ["(file is not valid TOML)"]
    if "bar" not in doc:
        return []
    bar = doc["bar"]
    return sorted(bar.keys()) if isinstance(bar, dict) and bar else ["[bar] table"]


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
        result = (base + "\n\n" if base else "") + BLOCK
        try:
            tomllib.loads(result)
        except tomllib.TOMLDecodeError as e:
            print(json.dumps({"error": "result would not be valid TOML (" + str(e) + ") — not changed"}))
            sys.exit(1)
        write(result)
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
