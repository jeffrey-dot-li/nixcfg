"""Link the Pi Coding extension from the Nix profile into VS Code / Cursor servers.

Run once per host (and again only if an editor server is wiped). Each server's
extensions dir gets a symlink to the extension inside the *profile*
(~/.nix-profile/share/vscode/extensions/<id>), not a store path, so every later
`nix profile upgrade` changes the code the server loads with no further step:
reload the window to pick it up.

Also, per server:
- registers the symlink in extensions.json (the server's source of truth),
- removes earlier copied installs (<id>-<version> dirs from VSIX installs),
- sets the machine setting piAgent.command to the profile's pi if unset.

Safe to re-run; it is idempotent.
"""

import json
import os
import shutil
import sys
import tempfile
import time

EXTENSION_ID = sys.argv[1]
PROFILE = os.path.expanduser(os.environ.get("PI_VSCODE_PROFILE", "~/.nix-profile"))
SERVERS = [os.path.expanduser(p) for p in ("~/.vscode-server", "~/.cursor-server")]


def log(msg):
    print(f"pi-vscode-link: {msg}")


def write_json(path, value):
    try:
        mode = os.stat(path).st_mode & 0o777
    except FileNotFoundError:
        mode = 0o644
    fd, tmp = tempfile.mkstemp(dir=os.path.dirname(path), prefix=".pi-vscode-link-")
    os.fchmod(fd, mode)
    with os.fdopen(fd, "w", encoding="utf-8") as f:
        json.dump(value, f, indent=4)
        f.write("\n")
    os.replace(tmp, path)


def load_json(path, default):
    try:
        with open(path, encoding="utf-8") as f:
            return json.load(f)
    except FileNotFoundError:
        return default


def link_server(server, target, version):
    ext_dir = os.path.join(server, "extensions")
    os.makedirs(ext_dir, exist_ok=True)
    link = os.path.join(ext_dir, EXTENSION_ID)

    registry_path = os.path.join(ext_dir, "extensions.json")
    try:
        registry = load_json(registry_path, [])
    except json.JSONDecodeError:
        log(f"{registry_path} is not valid JSON; leaving {server} untouched")
        return False

    # Drop every earlier registration of this extension (copied VSIX installs).
    kept = []
    for entry in registry:
        if entry.get("identifier", {}).get("id", "").lower() != EXTENSION_ID.lower():
            kept.append(entry)
            continue
        old = entry.get("location", {}).get("path") or entry.get("location", {}).get("fsPath")
        if old and os.path.realpath(os.path.dirname(old)) == os.path.realpath(ext_dir) and old != link:
            if os.path.isdir(old) and not os.path.islink(old):
                shutil.rmtree(old, ignore_errors=True)
                log(f"removed copied install {old}")

    if os.path.islink(link) or os.path.exists(link):
        if os.path.islink(link):
            os.unlink(link)
        else:
            shutil.rmtree(link)
    # Copied VSIX installs live in <id>-<version>[-<platform>] dirs, registered or not.
    for name in os.listdir(ext_dir):
        path = os.path.join(ext_dir, name)
        if name.lower().startswith(EXTENSION_ID.lower() + "-") and os.path.isdir(path) and not os.path.islink(path):
            shutil.rmtree(path, ignore_errors=True)
            log(f"removed copied install {path}")
    os.symlink(target, link)

    kept.append(
        {
            "identifier": {"id": EXTENSION_ID},
            "version": version,
            "location": {"$mid": 1, "fsPath": link, "external": f"file://{link}", "path": link, "scheme": "file"},
            "relativeLocation": EXTENSION_ID,
            "metadata": {
                "isApplicationScoped": False,
                "isMachineScoped": False,
                "isBuiltin": False,
                "installedTimestamp": int(time.time() * 1000),
                # Not on any marketplace; never try to update it from one.
                "pinned": True,
                "source": "vsix",
            },
        }
    )
    write_json(registry_path, kept)

    # A server marks uninstalled extensions in .obsolete; make sure ours is not.
    obsolete_path = os.path.join(ext_dir, ".obsolete")
    obsolete = load_json(obsolete_path, None)
    if isinstance(obsolete, dict):
        pruned = {k: v for k, v in obsolete.items() if not k.lower().startswith(EXTENSION_ID.lower())}
        if pruned != obsolete:
            write_json(obsolete_path, pruned)

    machine = os.path.join(server, "data", "Machine", "settings.json")
    os.makedirs(os.path.dirname(machine), exist_ok=True)
    try:
        settings = load_json(machine, {})
    except json.JSONDecodeError:
        log(f"{machine} has comments or is invalid; set piAgent.command there by hand")
    else:
        if "piAgent.command" not in settings:
            settings["piAgent.command"] = os.path.join(PROFILE, "bin", "pi")
            write_json(machine, settings)
            log(f"set piAgent.command in {machine}")

    log(f"{link} -> {target}")
    return True


def main():
    target = os.path.join(PROFILE, "share", "vscode", "extensions", EXTENSION_ID)
    manifest = os.path.join(target, "package.json")
    if not os.path.isfile(manifest):
        sys.exit(f"pi-vscode-link: {manifest} not found; is pi-vscode in {PROFILE}?")
    version = load_json(manifest, {}).get("version", "0.0.0")

    servers = [s for s in SERVERS if os.path.isdir(s)]
    if not servers:
        sys.exit("pi-vscode-link: no ~/.vscode-server or ~/.cursor-server; connect with the editor once first")
    linked = [s for s in servers if link_server(s, target, version)]
    if linked:
        log("done; run Developer: Reload Window in open remote windows")
    else:
        sys.exit(1)


main()
