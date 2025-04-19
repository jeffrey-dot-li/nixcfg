{
  inputs,
  lib,
}: {
  overlays = [
    (import inputs.rust-overlay)
  ];

  config = {
    allowInsecurePredicate = pkg: let
      pname = lib.getName pkg;
      byName = builtins.elem pname [
        "nix"
      ];
    in
      if byName
      then lib.warn "Allowing insecure package: ${pname}" true
      else false;

    allowUnfreePredicate = pkg: let
      pname = lib.getName pkg;
      byName = builtins.elem pname [
        "vscode"
        "slack"
        "steam"
        "nvidia-x11"
      ];
      byLicense = builtins.elem pkg.meta.license.shortName [
        "CUDA EULA"
        "bsl11"
      ];
    in
      if byName || byLicense || true
      then lib.warn "Allowing unfree package: ${pname}" true
      else false;
  };
}
