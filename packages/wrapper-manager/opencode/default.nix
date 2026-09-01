{
  pkgs,
  ...
}: let
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

      nativeBuildInputs = pkgs.lib.optional (pkgs.lib.hasSuffix ".zip" archive.name) pkgs.unzip;

      dontConfigure = true;
      dontBuild = true;
      dontStrip = true;

      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin
        install -m755 opencode $out/bin/opencode
        runHook postInstall
      '';

      meta = {
        description = "AI coding agent built for the terminal";
        homepage = "https://github.com/anomalyco/opencode";
        license = pkgs.lib.licenses.mit;
        mainProgram = "opencode";
        platforms = [
          "aarch64-darwin"
          "x86_64-darwin"
          "aarch64-linux"
          "x86_64-linux"
        ];
        sourceProvenance = [pkgs.lib.sourceTypes.binaryNativeCode];
      };
    };
  };
}
