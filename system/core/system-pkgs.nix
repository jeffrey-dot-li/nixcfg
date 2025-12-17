{pkgs, ...}: let
  # https://nixos.wiki/wiki/Visual_Studio_Code
  # https://code.visualstudio.com/updates/v1_101
  customVscode = (pkgs.vscode.override {}).overrideAttrs (oldAttrs: rec {
    src = builtins.fetchTarball {
      url = "https://update.code.visualstudio.com/1.101.2/darwin-universal/stable";
      sha256 = "0iwxc11k77xkp1a722wpqkanbl68z7n6rwb67sr0lkr356laqyy1";
    };
    version = "1.101";
  });
in {
  environment.systemPackages = with pkgs; [
    alejandra
    # uv
    lazygit
    # texlive.combined.scheme-full # This includes latexmk
    # (rust-bin.beta.latest.default.override {
    #   extensions = ["rust-src"];
    # })
    # TODO: Run rustup update after rustup
    rustup
    gcc
    pciutils
    (
      if stdenv.isDarwin
      then customVscode
      else vscode
    )
  ];
}
