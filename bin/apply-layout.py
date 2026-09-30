#!/usr/bin/env python3
"""Write an Amiga Bar layout into ~/.config/omarchy/shell.json.

Reads {"layout": {...}, "options": {...}, "pluginId": "..."} on stdin,
replaces bar.layout, stores the options in the plugin's plugins[] entry,
and writes atomically while keeping the file mode (shell.json is 0600).
Everything else in shell.json is left as it is.
"""
import json
import os
import sys
import tempfile
from pathlib import Path

path = Path(os.environ.get("OMARCHY_SHELL_JSON", Path.home() / ".config/omarchy/shell.json"))
req = json.load(sys.stdin)
cfg = json.loads(path.read_text())
bar = cfg.setdefault("bar", {})
bar["layout"] = req["layout"]
plugins = cfg.setdefault("plugins", [])
entry = next((p for p in plugins if isinstance(p, dict) and p.get("id") == req["pluginId"]), None)
if entry is None:
    entry = {"id": req["pluginId"]}
    plugins.append(entry)
entry["options"] = req["options"]
mode = path.stat().st_mode & 0o777
fd, tmp = tempfile.mkstemp(prefix=".shell-amiga-bar.", dir=path.parent)
with os.fdopen(fd, "w") as fh:
    fh.write(json.dumps(cfg, indent=2) + "\n")
os.chmod(tmp, mode)
os.replace(tmp, path)
print("ok")
