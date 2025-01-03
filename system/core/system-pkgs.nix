{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    alejandra
    uv
    lazygit
    # (rust-bin.beta.latest.default.override {
    #   extensions = ["rust-src"];
    # })
    # TODO: Run rustup update after rustup
    rustup
    vscode
    elan
    (
      pkgs.google-cloud-sdk.withExtraComponents [
        pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin
      ]
    )
  ];
}
