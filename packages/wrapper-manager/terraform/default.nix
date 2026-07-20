{pkgs, ...}: {
  wrappers.terraform = {
    basePackage = pkgs.terraform.overrideAttrs (_: {
      version = "1.14.0";

      src = pkgs.fetchFromGitHub {
        owner = "hashicorp";
        repo = "terraform";
        rev = "v1.14.0";
        hash = "sha256-G9GyrwELOuzQqTMimC+z2GJUjq+c5YJDoE313JSsX5w=";
      };

      vendorHash = "sha256-T6baxFk5lrmhyeJgcn7s5cF+utaogSQOD9S5omEKTZg=";
    });
  };
}
