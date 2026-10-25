{
  pkgs,
  lib,
  config,
  inputs,
  ...
}: {
  cachix.push = "jeffrey-dot-li";

  packages = [];

  scripts.export-vscode-settings = {
    description = "Export your VS Code settings and keybindings into config/ (optional args: settings.json path, keybindings.json path)";
    exec = ''
      ${pkgs.python3}/bin/python3 -I - "$@" <<'PY'
      import importlib.util, json, os, re, sys

      root = os.environ["DEVENV_ROOT"]
      editors = os.path.join(root, "packages/wrapper-manager/editors")
      spec = importlib.util.spec_from_file_location("sync", os.path.join(editors, "editor-sync.py"))
      sync = importlib.util.module_from_spec(spec)
      spec.loader.exec_module(sync)

      user_dir = "~/Library/Application Support/Code/User" if sys.platform == "darwin" else "~/.config/Code/User"
      args = sys.argv[1:] + [None, None]
      src = args[0] or os.path.expanduser(user_dir + "/settings.json")
      keys_src = args[1] or os.path.expanduser(user_dir + "/keybindings.json")
      out = os.path.join(editors, "config/settings.base.json")
      keys_out = os.path.join(editors, "config/keybindings.json")

      base = sync.load_jsonc(out) or {}
      home = os.path.expanduser("~")
      kept = {}
      for key, value in sync.load_jsonc(src).items():
          old = base.get(key)
          if isinstance(old, str) and re.fullmatch(r"@[A-Z_]+@", old):
              value = old  # tool path filled in by nix at build time
          elif isinstance(value, str) and ("/nix/store/" in value or home in value):
              print(f"skipped machine-specific {key}: {value}", file=sys.stderr)
              continue
          kept[key] = value
      for key, old in base.items():
          if isinstance(old, str) and re.fullmatch(r"@[A-Z_]+@", old):
              kept.setdefault(key, old)

      with open(out, "w", encoding="utf-8") as f:
          f.write(json.dumps(kept, indent=2) + "\n")
      print(f"wrote {len(kept)} settings from {src} to {out}")

      # Both the nix-managed entries and the ones you added below the marker
      # comment end up in the base; exact duplicates are dropped.
      seen, entries = set(), []
      for entry in sync.load_jsonc(keys_src) or []:
          dumped = json.dumps(entry, sort_keys=True)
          if dumped not in seen:
              seen.add(dumped)
              entries.append(entry)
      with open(keys_out, "w", encoding="utf-8") as f:
          f.write(json.dumps(entries, indent=2) + "\n")
      print(f"wrote {len(entries)} keybindings from {keys_src} to {keys_out}")
      PY
    '';
  };

  git-hooks.hooks.nix-fmt = {
    enable = true;
    name = "nix fmt (treefmt + alejandra)";
    entry = "nix fmt --";
    files = "\\.nix$";
    language = "system";
  };
}
