{pkgs, ...}: let
  inherit (pkgs) lib;
  version = "0.85.1";

  archive =
    {
      aarch64-darwin = {
        name = "pi-darwin-arm64.tar.gz";
        hash = "sha256-1fcOPAz3OY6sI5/QJh7gdNmLe6f2tD/jYX8FLtW3nQY=";
      };
      x86_64-darwin = {
        name = "pi-darwin-x64.tar.gz";
        hash = "sha256-rbkYuEViXxhNi+pAjVXqyvIaqHI4eTwPW087lze85is=";
      };
      aarch64-linux = {
        name = "pi-linux-arm64.tar.gz";
        hash = "sha256-BC0grohe5POxAoFfMoC5YsN3sun7RN5AN5CMxTDq5NQ=";
      };
      x86_64-linux = {
        name = "pi-linux-x64.tar.gz";
        hash = "sha256-SU5Jj0fXTSH0CzOG9qXpIaPUlTGhacq1W72soOof4lo=";
      };
    }.${
      pkgs.stdenv.hostPlatform.system
    };

  pi-unwrapped = pkgs.stdenvNoCC.mkDerivation {
    pname = "pi-unwrapped";
    inherit version;

    src = pkgs.fetchurl {
      url = "https://github.com/earendil-works/pi/releases/download/v${version}/${archive.name}";
      inherit (archive) hash;
    };

    sourceRoot = "pi";
    nativeBuildInputs = [pkgs.makeWrapper];
    dontConfigure = true;
    dontBuild = true;
    dontPatchELF = true;
    dontStrip = true;
    # Bun's Linux executable must retain and use its upstream loader. Invoking
    # it through a Nix loader changes its runtime behavior.
    doInstallCheck = !pkgs.stdenv.hostPlatform.isLinux;

    installPhase = ''
      runHook preInstall
      mkdir -p $out/libexec $out/bin
      cp -R . $out/libexec/pi
      makeWrapper $out/libexec/pi/pi $out/bin/pi
      runHook postInstall
    '';

    installCheckPhase = ''
      checkDir=$(mktemp -d)
      export HOME=$checkDir
      export TMPDIR=$checkDir
      $out/bin/pi --version
    '';

    meta = {
      description = "Minimal terminal coding harness";
      homepage = "https://github.com/earendil-works/pi";
      license = lib.licenses.mit;
      mainProgram = "pi";
      platforms = [
        "aarch64-darwin"
        "x86_64-darwin"
        "aarch64-linux"
        "x86_64-linux"
      ];
      sourceProvenance = [lib.sourceTypes.binaryNativeCode];
    };
  };
in {
  wrappers.pi = {
    basePackage = pi-unwrapped;
    env.PI_SKIP_VERSION_CHECK.value = "1";
  };
}
