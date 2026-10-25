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

  # Manifest of the curated extensions. The launch script symlinks each one
  # into the editor's normal (writable) extensions dir and merges these
  # entries into the editor's own `extensions.json`, so extensions installed
  # from the UI live next to them. Not using `pkgs.vscode-with-extensions`
  # because that helper hardcodes the Darwin app bundle's main executable to
  # "Electron", which is only true for upstream VS Code - Cursor's bundle
  # ships its main executable as "Cursor".
  extensionsJson = pkgs.writeText "extensions.json" (pkgs.vscode-utils.toExtensionJson extensions);

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

  # On every launch, layer the nix-managed config over the editor's mutable
  # `User` directory (rules are in editor-sync.py): nix wins for the settings
  # keys it sets, nix owns the part of keybindings.json above a marker comment,
  # and curated extensions are symlinked in next to user-installed ones.
  # Authentication, workspace history, caches, and other editor state are left
  # untouched, and a failure never stops the editor from starting.
  mkRestoreScript = {
    name,
    relUserDir,
    relExtensionsDir,
    settingsFile,
  }:
    pkgs.writeShellScript "sync-${name}-config" ''
      ${pkgs.python3}/bin/python3 -I ${./editor-sync.py} \
        --user-dir "$HOME/${relUserDir}" \
        --settings ${settingsFile} \
        --keybindings ${keybindingsFile} \
        --ext-dir "$HOME/${relExtensionsDir}" \
        --ext-json ${extensionsJson} || true
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
    relExtensionsDir,
    settingsFile,
  }: let
    restoreScript = mkRestoreScript {inherit name relUserDir relExtensionsDir settingsFile;};
  in {
    inherit basePackage;
    wrapperType = "shell";
    wrapFlags = [
      "--run"
      restoreScript
    ];
    # wrapper-manager handles executables in $out/bin. Finder launches the
    # executable inside the app bundle directly, so wrap that one as well.
    postBuild = lib.optionalString isDarwin ''
      appExecutable="$out/Applications/${longName}.app/Contents/MacOS/${appExecutableName}"
      if [ -e "$appExecutable" ]; then
        wrapProgram "$appExecutable" \
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
    relExtensionsDir = ".vscode/extensions";
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
    relExtensionsDir = ".cursor/extensions";
    settingsFile = cursorSettingsFile;
  };
}
