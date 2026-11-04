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
      rev = "6617e0bef22bc17111946c7821e33ea45e21c8c6";
      hash = "sha256-sgMu0McTv6mDnKRuhQ1a0SkcYJf4Rw0lyf+yeAWE2UQ=";
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
