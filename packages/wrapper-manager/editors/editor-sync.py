"""Sync nix-managed VS Code / Cursor config into the editor's mutable user dirs.

Run on every editor launch by the wrapper. Everything here is best effort and
never touches a file it cannot parse, so a broken user file cannot stop the
editor from starting.

- settings.json: nix-managed keys are merged over the user's file (nix wins on
  conflicts, every other key is left alone).
- keybindings.json: everything above MARKER is rewritten from nix, everything
  below it is left alone.
- extensions: nix-managed extensions are symlinked into the normal extensions
  dir next to user-installed ones.
"""

import argparse
import copy
import json
import os
import sys
import tempfile
import textwrap
import time

MARKER = "// ---- your keybindings go below this line; nix overwrites everything above it ----"
STORE = "/nix/store/"


def warn(msg):
    print(f"editor-sync: {msg}", file=sys.stderr)


def strip_jsonc(text):
    """Remove comments and trailing commas, leaving strings untouched."""
    out = []
    i, n, in_str = 0, len(text), False
    while i < n:
        c = text[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(text[i + 1])
                i += 2
                continue
            in_str = c != '"'
        elif c == '"':
            in_str = True
            out.append(c)
        elif text.startswith("//", i):
            while i < n and text[i] != "\n":
                i += 1
            continue
        elif text.startswith("/*", i):
            end = text.find("*/", i + 2)
            i = n if end < 0 else end + 2
            continue
        else:
            out.append(c)
        i += 1
    stripped = "".join(out)

    out = []
    i, n, in_str = 0, len(stripped), False
    while i < n:
        c = stripped[i]
        if in_str:
            out.append(c)
            if c == "\\" and i + 1 < n:
                out.append(stripped[i + 1])
                i += 2
                continue
            in_str = c != '"'
        elif c == '"':
            in_str = True
            out.append(c)
        elif c == ",":
            j = i + 1
            while j < n and stripped[j].isspace():
                j += 1
            if j < n and stripped[j] in "}]":
                i += 1
                continue
            out.append(c)
        else:
            out.append(c)
        i += 1
    return "".join(out)


def load_jsonc(path):
    with open(path, encoding="utf-8") as f:
        text = f.read()
    return json.loads(strip_jsonc(text)) if text.strip() else None


def write_atomic(path, text):
    directory = os.path.dirname(path)
    fd, tmp = tempfile.mkstemp(dir=directory, prefix=".editor-sync-")
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        f.write(text)
    os.replace(tmp, path)


def backup(path):
    dest = f"{path}.bak-{int(time.time())}"
    os.replace(path, dest)
    warn(f"backed up {path} to {dest}")


def materialize_link(path):
    """Replace a symlink (e.g. from the old read-only setup) with a real copy."""
    if not os.path.islink(path):
        return
    try:
        with open(path, encoding="utf-8") as f:
            text = f.read()
    except OSError:
        text = None
    os.unlink(path)
    if text is not None:
        write_atomic(path, text)


def merge(user, base):
    """Return `user` with every key in `base` applied on top (base wins)."""
    result = copy.deepcopy(user)
    for key, value in base.items():
        if isinstance(value, dict) and isinstance(result.get(key), dict):
            result[key] = merge(result[key], value)
        else:
            result[key] = copy.deepcopy(value)
    return result


def sync_settings(path, base_path):
    base = load_jsonc(base_path)
    materialize_link(path)
    if not os.path.exists(path):
        write_atomic(path, json.dumps(base, indent=2) + "\n")
        return
    try:
        user = load_jsonc(path)
    except ValueError as err:
        warn(f"{path} is not valid JSONC ({err}); leaving it untouched")
        return
    if not isinstance(user, dict):
        user = {}
    merged = merge(user, base)
    # Only rewrite when something changed, so comments in the user's file
    # survive launches where nix has nothing new to say.
    if merged != user:
        write_atomic(path, json.dumps(merged, indent=2) + "\n")


def render_entries(entries):
    return "".join(textwrap.indent(json.dumps(e, indent=2), "  ") + ",\n" for e in entries)


def sync_keybindings(path, source):
    managed = load_jsonc(source) or []
    materialize_link(path)

    user_part = ""
    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            text = f.read()
        lines = text.split("\n")
        marker_at = next((i for i, l in enumerate(lines) if l.strip() == MARKER), None)
        if marker_at is not None:
            tail = "\n".join(lines[marker_at + 1 :])
            end = tail.rfind("]")
            user_part = tail[:end] if end >= 0 else ""
        elif text.strip():
            # A file we have never managed: keep its entries below the marker.
            try:
                existing = load_jsonc(path) or []
                user_part = render_entries(existing)
            except ValueError as err:
                warn(f"{path} is not valid JSONC ({err}); starting fresh")
            backup(path)

    user_part = user_part.strip("\n")
    new_text = "[\n" + render_entries(managed) + "  " + MARKER + "\n"
    if user_part.strip():
        new_text += user_part + "\n"
    new_text += "]\n"

    if os.path.exists(path):
        with open(path, encoding="utf-8") as f:
            if f.read() == new_text:
                return
    write_atomic(path, new_text)


def sync_extensions(ext_dir, ext_json):
    os.makedirs(ext_dir, exist_ok=True)
    with open(ext_json, encoding="utf-8") as f:
        wanted = json.load(f)
    targets = {e["relativeLocation"]: e["location"]["path"] for e in wanted}

    stale = set()
    for name in os.listdir(ext_dir):
        link = os.path.join(ext_dir, name)
        if os.path.islink(link) and os.readlink(link).startswith(STORE) and name not in targets:
            os.unlink(link)
            stale.add(name)

    linked = set()
    for name, target in targets.items():
        link = os.path.join(ext_dir, name)
        if os.path.islink(link):
            if os.readlink(link) != target:
                os.unlink(link)
                os.symlink(target, link)
            linked.add(name)
        elif os.path.exists(link):
            warn(f"{link} already exists and is not managed; skipping")
        else:
            os.symlink(target, link)
            linked.add(name)

    manifest_path = os.path.join(ext_dir, "extensions.json")
    try:
        manifest = load_jsonc(manifest_path) if os.path.exists(manifest_path) else []
    except ValueError as err:
        warn(f"{manifest_path} is not valid JSON ({err}); leaving it untouched")
        return
    if not isinstance(manifest, list):
        manifest = []

    kept = [e for e in manifest if e.get("relativeLocation") not in stale | linked]
    for entry in wanted:
        name = entry["relativeLocation"]
        if name not in linked:
            continue
        entry = copy.deepcopy(entry)
        entry["location"]["path"] = entry["location"]["fsPath"] = os.path.join(ext_dir, name)
        kept.append(entry)

    if kept != manifest:
        write_atomic(manifest_path, json.dumps(kept))


def main():
    parser = argparse.ArgumentParser()
    parser.add_argument("--user-dir", required=True)
    parser.add_argument("--settings", required=True)
    parser.add_argument("--keybindings", required=True)
    parser.add_argument("--ext-dir", required=True)
    parser.add_argument("--ext-json", required=True)
    args = parser.parse_args()

    os.makedirs(args.user_dir, exist_ok=True)
    steps = [
        ("settings", lambda: sync_settings(os.path.join(args.user_dir, "settings.json"), args.settings)),
        ("keybindings", lambda: sync_keybindings(os.path.join(args.user_dir, "keybindings.json"), args.keybindings)),
        ("extensions", lambda: sync_extensions(args.ext_dir, args.ext_json)),
    ]
    for name, step in steps:
        try:
            step()
        except (OSError, ValueError, KeyError) as err:
            warn(f"{name} sync failed: {err}")


if __name__ == "__main__":
    main()
