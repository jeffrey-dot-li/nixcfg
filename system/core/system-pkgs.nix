{pkgs, ...}: {
  environment.systemPackages = with pkgs; [
    alejandra
    uv
    (rust-bin.beta.latest.default.override {
      extensions = ["rust-src"];
    })
    lazygit
    # (rust-bin.beta.latest.default.override {
    #   extensions = ["rust-src"];
    # })
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
