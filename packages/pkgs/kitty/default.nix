{
  pkgs,
  ...
}: let
  kitty = pkgs.kitty;
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
in
  pkgs.symlinkJoin {
    name = "kitty-configured-${kitty.version}";
    paths = [kitty];
    nativeBuildInputs = [pkgs.makeWrapper];

    postBuild = ''
      wrapProgram "$out/bin/kitty" \
        --set KITTY_CONFIG_DIRECTORY ${configDirectory}

      appExecutable="$out/Applications/kitty.app/Contents/MacOS/kitty"
      if [ -e "$appExecutable" ]; then
        wrapProgram "$appExecutable" \
          --set KITTY_CONFIG_DIRECTORY ${configDirectory}
      fi
    '';

    passthru = {
      inherit configDirectory;
      unwrapped = kitty;
    };
    meta = kitty.meta;
  }
