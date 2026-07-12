{
  pkgs,
  ...
}: let
  openCommand =
    if pkgs.stdenv.hostPlatform.isDarwin
    then "/usr/bin/open"
    else "${pkgs.xdg-utils}/bin/xdg-open";
  openGcsUrl = pkgs.writeShellScript "kitty-open-gcs-url" ''
    set -eu
    case "''${URL:-}" in
      gs://*) exec ${openCommand} "https://console.cloud.google.com/storage/browser/''${URL#gs://}" ;;
      *) exit 1 ;;
    esac
  '';
  openActions = pkgs.writeText "kitty-open-actions.conf" ''
    protocol gs
    action launch --type=background ${openGcsUrl}
  '';
  configDirectory = pkgs.linkFarm "kitty-config" [
    {
      name = "kitty.conf";
      path = ./kitty.conf;
    }
    {
      name = "open-actions.conf";
      path = openActions;
    }
    {
      name = "popping-n-locking-theme.conf";
      path = ./popping-n-locking-theme.conf;
    }
    {
      name = "theme.conf";
      path = ./theme.conf;
    }
  ];
in {
  wrappers.kitty = {
    basePackage = pkgs.kitty;
    env.KITTY_CONFIG_DIRECTORY.value = toString configDirectory;

    # wrapper-manager handles executables in $out/bin. Finder launches the
    # executable inside the app bundle directly, so wrap that one as well.
    postBuild = ''
      appExecutable="$out/Applications/kitty.app/Contents/MacOS/kitty"
      if [ -e "$appExecutable" ]; then
        wrapProgram "$appExecutable" \
          --set KITTY_CONFIG_DIRECTORY ${configDirectory}
      fi
    '';
  };
}
