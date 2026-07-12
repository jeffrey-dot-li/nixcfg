{pkgs, ...}: {
  # VS Code and Cursor are provided by this flake's `vscode` and `cursor`
  # packages (see packages/wrapper-manager/editors), which are already
  # installed via `self'.packages` on nix-darwin and NixOS. Installing the
  # unconfigured upstream `pkgs.vscode` here would reintroduce the settings
  # drift this repository packages the editors to avoid.
  environment.systemPackages = with pkgs; [
    alejandra
    # uv
    # texlive.combined.scheme-full # This includes latexmk
    # (rust-bin.beta.latest.default.override {
    #   extensions = ["rust-src"];
    # })
    # TODO: Run rustup update after rustup
    rustup
    gcc
    pciutils
  ];
}
