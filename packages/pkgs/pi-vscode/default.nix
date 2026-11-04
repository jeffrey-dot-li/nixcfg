# Pi Coding VS Code / Cursor extension, built from my fork of
# https://github.com/dcalsky/pi-vscode. It runs the real `pi` from PATH in a
# native terminal editor, with a session sidebar, per-session status, an audio
# cue when a session starts waiting, and reopening of open sessions on reload.
#
# Outputs:
#   $out/share/vscode/extensions/<id>   unpacked extension (editors module symlinks it locally)
#   $out/share/pi-vscode/pi-coding.vsix  VSIX, for hosts without this package in a profile
#   $out/bin/pi-vscode-link              one-time setup on an SSH remote: links the
#                                        extension from ~/.nix-profile into the VS Code /
#                                        Cursor servers, so `nix profile upgrade` updates
#                                        it with no install step (see link-remote.py)
#   $out/bin/pi-vscode-install           alias of pi-vscode-link
#   $out/bin/pi-vscode-pi                piAgent.command on remotes: starts pi the way a
#                                        terminal would (login fish + direnv for the cwd)
{
  lib,
  buildNpmPackage,
  fetchFromGitHub,
  jq,
  vsce,
  unzip,
  python3,
  writeShellScript,
}: let
  # Published upstream as `EthanChow.pi-coding`. Rename the publisher so the
  # marketplace never "updates" the fork to upstream, and so a remote install
  # cannot silently pull the upstream build from the gallery instead.
  publisher = "jeffrey-dot-li";
  name = "pi-coding";
  extensionId = "${publisher}.${name}";
in
  buildNpmPackage (finalAttrs: {
    pname = "pi-vscode";
    version = "0.0.61-unstable-2026-11-04";

    src = fetchFromGitHub {
      owner = "jeffrey-dot-li";
      repo = "pi-vscode";
      rev = "8d38755a68b62e02e6c9dd67b7b20a5ce744bde5";
      hash = "sha256-ZynNsD/uC4CB0tto7/a23ICPGuG5IyCCLSb3nxQfrvw=";
    };

    npmDepsHash = "sha256-P7I8Pa2eFfMzNtBx7JAYWZ86xQHQSwcd7y/Gfnzc9vA=";

    # node-pty ships prebuilt pty.node for darwin/linux (x64 + arm64), so the
    # install script (node-gyp source build) is unnecessary, and skipping it
    # keeps the VSIX portable across the Mac and the Linux VM.
    npmFlags = ["--ignore-scripts"];
    npmRebuildFlags = ["--ignore-scripts"];

    nativeBuildInputs = [vsce unzip];

    postPatch = ''
      ${lib.getExe jq} '.publisher = "${publisher}" | .repository.url = "https://github.com/jeffrey-dot-li/pi-vscode.git"' \
        package.json > package.json.new
      mv package.json.new package.json
    '';

    buildPhase = ''
      runHook preBuild
      npm run compile
      # vsce reads node_modules to bundle production dependencies; no network.
      vsce package --allow-missing-repository --skip-license -o pi-coding.vsix
      runHook postBuild
    '';

    installPhase = ''
      runHook preInstall
      mkdir -p $out/share/pi-vscode $out/share/vscode/extensions/${extensionId} $out/bin
      cp pi-coding.vsix $out/share/pi-vscode/pi-coding.vsix
      unzip -q pi-coding.vsix 'extension/*' -d unpacked
      cp -r unpacked/extension/. $out/share/vscode/extensions/${extensionId}/
      install -m755 ${finalAttrs.passthru.linkScript} $out/bin/pi-vscode-link
      ln -s pi-vscode-link $out/bin/pi-vscode-install
      install -m755 ${finalAttrs.passthru.launchScript} $out/bin/pi-vscode-pi
      runHook postInstall
    '';

    # Keep the prebuilt node-pty binaries untouched (autoPatchelf / strip would
    # rewrite the Linux pty.node for the Nix store, breaking it on a plain VM).
    dontFixup = true;

    passthru = {
      inherit extensionId;
      # The editors module (vscode-utils.toExtensionJson) reads these.
      vscodeExtPublisher = publisher;
      vscodeExtName = name;
      vscodeExtUniqueId = extensionId;
      # The editor server (and so the extension host that spawns pi) is started
      # by a non-interactive SSH bash: no fish config, no ~/.nix-profile on PATH,
      # no direnv. Run pi through a login fish with direnv applied for the
      # session's folder, so agents get the same tools and environment as pi in
      # an integrated terminal. The extension's arguments arrive as $argv.
      launchScript = writeShellScript "pi-vscode-pi" ''
        shell="''${PI_VSCODE_SHELL:-$HOME/.nix-profile/bin/fish}"
        if [ -x "$shell" ]; then
          exec "$shell" -l -c 'command -q direnv; and direnv export fish 2>/dev/null | source; exec pi $argv' -- "$@"
        fi
        # No fish: a bash login shell still puts the profile on PATH.
        exec bash -lc 'command -v direnv >/dev/null && eval "$(direnv export bash 2>/dev/null)"; exec pi "$@"' pi "$@"
      '';
      linkScript = writeShellScript "pi-vscode-link" ''
        exec ${lib.getExe python3} -I ${./link-remote.py} ${extensionId} "$@"
      '';
    };

    meta = {
      description = "Pi coding agent sessions in VS Code / Cursor (fork of dcalsky/pi-vscode)";
      homepage = "https://github.com/jeffrey-dot-li/pi-vscode";
      license = lib.licenses.mit;
    };
  })
