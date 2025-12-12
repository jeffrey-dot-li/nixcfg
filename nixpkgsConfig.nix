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
        "steam-unwrapped"
      ];
      byLicense =
        builtins.any (license: (builtins.elem license.shortName [
          "CUDA EULA"
          "bsl11"
        ]))
        (
          if builtins.isList pkg.meta.license
          then pkg.meta.license
          else [pkg.meta.license]
        );
    in
      if byName || byLicense || true
      then lib.warn "Allowing unfree package: ${pname}" true
      else false;
  };
}
