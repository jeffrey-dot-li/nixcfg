{pkgs, ...}: let
  version = "0.153.4";

  rustTarget =
    {
      aarch64-darwin = "aarch64-apple-darwin";
      x86_64-darwin = "x86_64-apple-darwin";
      aarch64-linux = "aarch64-unknown-linux-musl";
      x86_64-linux = "x86_64-unknown-linux-musl";
    }.${
      pkgs.stdenv.hostPlatform.system
    };

  src = pkgs.fetchurl {
    url = "https://github.com/openai/codex/releases/download/rust-v${version}/codex-${rustTarget}.tar.gz";
    hash =
      {
        aarch64-apple-darwin = "sha256-jPkR6mdlI7+yEh7FYYSNKrpWSJCtU2202KM1PyuYULE=";
        x86_64-apple-darwin = "sha256-1pIA8L+EGx0aB/gLgM90Ki5Pwrq5GuikSxBC+OjKn6Q=";
        aarch64-unknown-linux-musl = "sha256-XNphgr2Uw6MPLrY6SVSJ6/f2kf3bFNcPSMbBpQcbbN4=";
        x86_64-unknown-linux-musl = "sha256-9HlCTsoJJITcQNh64oxE9MxAI0pgBF1hMeSTgA2BSjA=";
      }.${
        rustTarget
      };
  };
in {
  wrappers.codex = {
    basePackage = pkgs.stdenv.mkDerivation {
      pname = "codex";
      inherit version src;

      sourceRoot = ".";

      nativeBuildInputs = [pkgs.installShellFiles];

      dontConfigure = true;
      dontBuild = true;
      dontStrip = true;

      doInstallCheck = true;

      installCheckPhase = ''
        $out/bin/codex --version
      '';

      installPhase = ''
        runHook preInstall
        mkdir -p $out/bin
        install -m755 codex-${rustTarget} $out/bin/codex
        runHook postInstall
      '';

      postInstall = pkgs.lib.optionalString (pkgs.stdenv.buildPlatform.canExecute pkgs.stdenv.hostPlatform) ''
        installShellCompletion --cmd codex \
          --bash <($out/bin/codex completion bash) \
          --fish <($out/bin/codex completion fish) \
          --zsh <($out/bin/codex completion zsh)
      '';

      meta = {
        description = "Lightweight coding agent that runs in your terminal";
        homepage = "https://github.com/openai/codex";
        license = pkgs.lib.licenses.asl20;
        mainProgram = "codex";
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
