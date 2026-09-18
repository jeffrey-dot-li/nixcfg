{pkgs, ...}: let
  inherit (pkgs) lib;
  version = "1.18.25";

  archive =
    {
      aarch64-darwin = {
        name = "opencode-darwin-arm64.zip";
        hash = "sha256-YGsJci2YBpYF4WA3+4w8fI67/tm6cTB5pe+y5bBlric=";
      };
      x86_64-darwin = {
        name = "opencode-darwin-x64.zip";
        hash = "sha256-bFxWn3ebGX4d9jkMYieLvfDnPnzCSKQpZIaAxjpvPxw=";
      };
      aarch64-linux = {
        name = "opencode-linux-arm64-musl.tar.gz";
        hash = "sha256-6RRNyghMLM6HoIaOEg5Xzc/8F70LaN9qkuGK8sL1LeA=";
      };
      x86_64-linux = {
        name = "opencode-linux-x64-musl.tar.gz";
        hash = "sha256-K8wczo75jmrD16S4cDQp+gcLm1lpskfaz6G+8fW27UQ=";
      };
    }.${
      pkgs.stdenv.hostPlatform.system
    };

  opencode-unwrapped = pkgs.stdenvNoCC.mkDerivation {
    pname = "opencode-unwrapped";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/anomalyco/opencode/releases/download/v${version}/${archive.name}";
      inherit (archive) hash;
    };

    sourceRoot = ".";
    nativeBuildInputs = lib.optional (lib.hasSuffix ".zip" archive.name) pkgs.unzip;
    dontConfigure = true;
    dontBuild = true;
    dontPatchELF = true;
    dontStrip = true;
    doInstallCheck = !pkgs.stdenv.hostPlatform.isLinux;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/bin
      install -m755 opencode $out/bin/opencode
      runHook postInstall
    '';

    installCheckPhase = ''
      checkDir=$(mktemp -d)
      export HOME=$checkDir
      export TMPDIR=$checkDir
      $out/bin/opencode --version
    '';

    meta = {
      description = "AI coding agent built for the terminal";
      homepage = "https://github.com/anomalyco/opencode";
      license = lib.licenses.mit;
      mainProgram = "opencode";
      platforms = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  };

  # Bun networking breaks with the Nix glibc runtime, so keep the musl
  # release untouched and invoke it with its matching loader and C++ runtime.
  muslPkgs = pkgs.pkgsMusl;
  muslLoader =
    {
      aarch64-linux = "ld-musl-aarch64.so.1";
      x86_64-linux = "ld-musl-x86_64.so.1";
    }.${
      pkgs.stdenv.hostPlatform.system
    };

  opencode =
    if pkgs.stdenv.hostPlatform.isLinux
    then
      pkgs.writeShellApplication {
        name = "opencode";
        derivationArgs = {inherit version;};
        text = ''
          exec ${muslPkgs.stdenv.cc.libc}/lib/${muslLoader} \
            --library-path ${lib.makeLibraryPath [muslPkgs.stdenv.cc.cc.lib muslPkgs.stdenv.cc.cc.libgcc]} \
            ${lib.getExe opencode-unwrapped} "$@"
        '';
        inherit (opencode-unwrapped) meta;
      }
    else opencode-unwrapped;
in {
  wrappers.opencode = {
    basePackage = opencode;

    # The built-in `websearch` tool only loads on the OpenCode/Go provider
    # or when an enable flag is set. Pin the Exa backend so it is always
    # available - Exa also honors the tool's depth/result-count/live-crawl
    # parameters, which the Parallel backend ignores.
    env.OPENCODE_ENABLE_EXA.value = "1";
  };
}
