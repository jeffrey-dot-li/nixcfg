{
  pkgs,
  ...
}: let
  inherit (pkgs) lib;
  version = "1.18.25";

  # Linux uses the glibc builds so autoPatchelfHook can retarget the
  # interpreter. The musl archives are still dynamically linked to
  # /lib/ld-musl-*.so.1, which NixOS does not provide.
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
        name = "opencode-linux-arm64.tar.gz";
        hash = "sha256-Ne93iXQl5BtRg6LCGsT7HU2UTYKpTjySD1e1SQrxGsU=";
      };
      x86_64-linux = {
        name = "opencode-linux-x64.tar.gz";
        hash = "sha256-WKNymm80Mt1tKRf8xKlJeIiRoDWBhkatSA4SyUf1bng=";
      };
    }.${
      pkgs.stdenv.hostPlatform.system
    };
in {
  wrappers.opencode = {
    basePackage = pkgs.stdenv.mkDerivation {
      pname = "opencode";
      inherit version;

      src = pkgs.fetchurl {
        url = "https://github.com/anomalyco/opencode/releases/download/v${version}/${archive.name}";
        inherit (archive) hash;
      };

      sourceRoot = ".";

      nativeBuildInputs =
        lib.optionals pkgs.stdenv.hostPlatform.isLinux [pkgs.autoPatchelfHook]
        ++ lib.optional (lib.hasSuffix ".zip" archive.name) pkgs.unzip;

      # Bun lists the dynamic linker as DT_NEEDED, which is not a library.
      autoPatchelfIgnoreMissingDeps = [
        "ld-linux-x86-64.so.2"
        "ld-linux-aarch64.so.1"
      ];

      dontConfigure = true;
      dontBuild = true;
      dontStrip = true;

      doInstallCheck = true;

      # Bun needs a writable home and tmp dir (without a home it falls back
      # to mkdir /homeless-shelter). On Darwin $TMPDIR is the build
      # directory, which contains the unpacked source binary `opencode`, so
      # Bun's state directory mkdir would collide with it - use a unique
      # temp dir for both.
      installCheckPhase = ''
        checkDir=$(mktemp -d)
        export HOME=$checkDir
        export TMPDIR=$checkDir
        $out/bin/opencode --version
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin
        install -m755 opencode $out/bin/opencode
        runHook postInstall
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

    # The built-in `websearch` tool only loads on the OpenCode/Go provider
    # or when an enable flag is set. Pin the Exa backend so it is always
    # available - Exa also honors the tool's depth/result-count/live-crawl
    # parameters, which the Parallel backend ignores.
    env.OPENCODE_ENABLE_EXA.value = "1";
  };
}
