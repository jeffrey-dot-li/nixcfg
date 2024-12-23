{
  pkgs,
  lib,
  ...
}: {
  environment.systemPackages = with pkgs; [
    alejandra
    elan
    (
      pkgs.google-cloud-sdk.withExtraComponents [
        pkgs.google-cloud-sdk.components.gke-gcloud-auth-plugin
      ]
    )
  ];
}
