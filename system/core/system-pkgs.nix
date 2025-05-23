{pkgs, ...}: {
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
    pciutils
    vscode
    elan
    (
      pkgs.google-cloud-sdk.withExtraComponents [
        pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin
      ]
    )
  ];
}
