{
  pkgs,
  ...
}: {
  wrappers.tflint = {
    basePackage = pkgs.buildGo126Module {
      pname = "tflint";
      version = "0.62.1";

      src = pkgs.fetchFromGitHub {
        owner = "terraform-linters";
        repo = "tflint";
        tag = "v0.62.1";
        hash = "sha256-0Q3VW4KjpFxRyhiTsocQ6fXti51y/mpeJ5SMlSgZobY=";
      };

      vendorHash = "sha256-kHtZXUUH8xMkqkpI5zsZG6kPg8LIvXFye+b1N3K/oDc=";

      doCheck = false;
      env.CGO_ENABLED = 0;
      subPackages = ["."];
      ldflags = [
        "-s"
        "-w"
      ];

      doInstallCheck = true;
      nativeInstallCheckInputs = [pkgs.versionCheckHook];

      meta = pkgs.tflint.meta;
    };
  };
}
