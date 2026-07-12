{
  pkgs,
  lib,
  ...
}: let
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;

  # Curated core extension set, shared between VS Code and Cursor. Keep this
  # list small and intentional - it's the installed source of truth, not a
  # mirror of everything that has ever been enabled interactively.
  curatedExtensions = with pkgs.vscode-extensions; [
    asvetliakov.vscode-neovim
    jnoortheen.nix-ide
    eamodio.gitlens
    usernamehw.errorlens
    pkief.material-icon-theme
    streetsidesoftware.code-spell-checker
    esbenp.prettier-vscode
  ];

  # Package `theme.json` as a minimal local extension so it installs the same
  # way as any other curated extension.
  customTheme = pkgs.vscode-utils.buildVscodeExtension {
    pname = "nixcfg-custom-theme";
    version = "1.0.0";
    vscodeExtPublisher = "nixcfg";
    vscodeExtName = "custom-theme";
    vscodeExtUniqueId = "nixcfg.custom-theme";
    src = ./config/theme;
    dontUnpack = true;
    installPhase = ''
      runHook preInstall
      mkdir -p "$out/$installPrefix"
      cp -r "$src"/. "$out/$installPrefix/"
      runHook postInstall
    '';
  };

  extensions = curatedExtensions ++ [customTheme];

  # Same mechanism `pkgs.vscode-with-extensions` uses internally to select a
  # pre-installed extension set via `--extensions-dir`. Built directly here
  # (rather than delegating to `vscode-with-extensions`) because that helper
  # hardcodes the app bundle's main executable name to "Electron" on Darwin,
  # which is only true for upstream VS Code - Cursor's bundle ships its main
  # executable as "Cursor".
  extensionsDir = pkgs.buildEnv {
    name = "vscode-extensions";
    paths =
      extensions
      ++ [
        (pkgs.writeTextFile {
          name = "vscode-extensions-json";
          destination = "/share/vscode/extensions/extensions.json";
          text = pkgs.vscode-utils.toExtensionJson extensions;
        })
      ];
  };
  extensionsDirFlag = "--extensions-dir ${extensionsDir}/share/vscode/extensions";

  # Base settings shared by both editors. Machine-specific values (home
  # directories, downloaded tool paths, fixed store paths from a previous
  # generation) have been stripped from the source JSON; the placeholders
  # below are re-substituted with real package paths from this closure once
  # the final JSON text has been generated (substituting before parsing would
  # lose the string context Nix uses to track store-path dependencies, since
  # `builtins.fromJSON`/`toJSON` do not preserve it).
  baseSettings = builtins.fromJSON (builtins.readFile ./config/settings.base.json);
  cursorOverrides = builtins.fromJSON (builtins.readFile ./config/settings.cursor-overrides.json);

  vscodeSettings = baseSettings;
  cursorSettings = lib.recursiveUpdate baseSettings cursorOverrides;

  substituteToolPaths = text:
    builtins.replaceStrings
    ["@NVIM_BIN@" "@NIL_BIN@" "@ALEJANDRA_BIN@" "@GIT_BIN@"]
    [(lib.getExe pkgs.nvim-min) (lib.getExe pkgs.nil) (lib.getExe pkgs.alejandra) (lib.getExe pkgs.git)]
    text;

  # `builtins.toJSON` produces a single minified line. Pretty-print through
  # `jq` so the settings file is actually readable if opened directly (the
  # editor's own formatter may not run against a read-only, symlinked file).
  mkPrettyJson = name: text: let
    raw = pkgs.writeText "${name}-raw" text;
  in
    pkgs.runCommand name {nativeBuildInputs = [pkgs.jq];} ''
      jq . ${raw} > $out
    '';

  vscodeSettingsFile = mkPrettyJson "vscode-settings.json" (substituteToolPaths (builtins.toJSON vscodeSettings));
  cursorSettingsFile = mkPrettyJson "cursor-settings.json" (substituteToolPaths (builtins.toJSON cursorSettings));
  keybindingsFile = ./config/keybindings.json;

  # Restore the managed settings/keybindings symlinks in the editor's `User`
  # directory on every launch. Authentication, workspace history, caches, and
  # other editor state under the same directory are left untouched. A
  # pre-existing regular file is backed up once, the first time it is
  # replaced by a managed symlink.
  mkRestoreScript = {
    name,
    relUserDir,
    settingsFile,
  }:
    pkgs.writeShellScript "restore-${name}-settings" ''
      set -eu
      target_dir="$HOME/${relUserDir}"
      mkdir -p "$target_dir"

      restore_link() {
        managed="$1"
        dest="$2"
        if [ -L "$dest" ]; then
          if [ "$(readlink "$dest")" = "$managed" ]; then
            return 0
          fi
          rm -f "$dest"
        elif [ -e "$dest" ]; then
          mv "$dest" "$dest.bak-$(date +%s)"
        fi
        ln -s "$managed" "$dest"
      }

      restore_link "${settingsFile}" "$target_dir/settings.json"
      restore_link "${keybindingsFile}" "$target_dir/keybindings.json"
    '';

  # Build one editor's wrapper-manager configuration. `appExecutableName` is
  # the name of the real executable inside the Darwin app bundle's
  # `Contents/MacOS/`, which differs between VS Code ("Electron") and Cursor
  # ("Cursor").
  mkEditor = {
    name,
    basePackage,
    longName,
    appExecutableName,
    relUserDir,
    settingsFile,
  }: let
    restoreScript = mkRestoreScript {inherit name relUserDir settingsFile;};
  in {
    inherit basePackage;
    wrapperType = "shell";
    wrapFlags = [
      "--add-flags"
      extensionsDirFlag
      "--run"
      restoreScript
    ];
    # wrapper-manager handles executables in $out/bin. Finder launches the
    # executable inside the app bundle directly, so wrap that one as well.
    postBuild = lib.optionalString isDarwin ''
      appExecutable="$out/Applications/${longName}.app/Contents/MacOS/${appExecutableName}"
      if [ -e "$appExecutable" ]; then
        wrapProgram "$appExecutable" \
          --add-flags ${lib.escapeShellArg extensionsDirFlag} \
          --run ${lib.escapeShellArg (toString restoreScript)}
      fi
    '';
  };
in {
  wrappers.vscode = mkEditor {
    name = "vscode";
    basePackage = pkgs.vscode;
    longName = "Visual Studio Code";
    appExecutableName = "Electron";
    relUserDir =
      if isDarwin
      then "Library/Application Support/Code/User"
      else ".config/Code/User";
    settingsFile = vscodeSettingsFile;
  };

  wrappers.cursor = mkEditor {
    name = "cursor";
    basePackage = pkgs.code-cursor;
    longName = "Cursor";
    appExecutableName = "Cursor";
    relUserDir =
      if isDarwin
      then "Library/Application Support/Cursor/User"
      else ".config/Cursor/User";
    settingsFile = cursorSettingsFile;
  };
}
