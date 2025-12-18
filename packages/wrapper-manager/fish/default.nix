{
  lib,
  pkgs,
  ...
}: let
  inherit (pkgs) writeTextDir formats;
  vendorConf = "share/fish/vendor_conf.d";
  loadPlugin =
    writeTextDir "${vendorConf}/viper_load.fish"
    # fish
    ''
      function viper_load_plugin
        if test (count $argv) -lt 1
          echo Failed to load plugin, incorrect number of arguments
          return 1
        end
        set -l __plugin_dir $argv[1]/share/fish
        if test -d $__plugin_dir/vendor_functions.d
          set -p fish_function_path $__plugin_dir/vendor_functions.d
        end
        if test -d $__plugin_dir/vendor_completions.d
          set -p fish_complete_path $__plugin_dir/vendor_completions.d
        end
        if test -d $__plugin_dir/vendor_conf.d
          for f in $__plugin_dir/vendor_conf.d/*.fish
            source $f
          end
        end
      end
    '';
  direnvConfig = writeTextDir "direnvrc" ''
    source ${pkgs.nix-direnv}/share/nix-direnv/direnvrc
  '';

  toml = formats.toml {};
  starship-settings = import ./starship.nix;

  # TODO: Nixify kitty config
  # todo: fzf-fish is broken here on mac
  isDarwin = pkgs.stdenv.hostPlatform.isDarwin;
  fzf_plugin =
    if isDarwin
    then pkgs.fzf
    else pkgs.fishPlugins.fzf-fish;

  fish_user_config =
    writeTextDir "${vendorConf}/viper_config.fish"
    ''
      # Only source once
      # set -q __fish_config_sourced; and exit
      # set -gx __fish_config_sourced 1

      ${
        lib.concatStringsSep "\n" (
          map
          (elem: "viper_load_plugin ${elem}")
          (with pkgs.fishPlugins; [
            foreign-env
            fzf_plugin
            bass
          ])
        )
      }

      # NixOS's /etc/profile already exits early with __ETC_PROFILE_SOURCED
      # For some reason, status is-login doesn't work consistently
      # fenv source /etc/profile

      if status is-login
        fenv source /etc/profile
      end
      ${lib.fileContents ./ssh.fish}

      if status is-interactive
        ${lib.fileContents ./interactive.fish}
        ${lib.fileContents ./pushd_mod.fish}
        ${lib.fileContents ./direnv.fish}
        ${lib.fileContents ./open.fish}
        set -gx EDITOR ${lib.getExe pkgs.nvim}

        set -gx STARSHIP_CONFIG ${toml.generate "starship.toml" starship-settings}
        function starship_transient_prompt_func
          ${lib.getExe pkgs.starship} module character
        end
        ${lib.getExe pkgs.starship} init fish | source
        ${lib.getExe pkgs.zoxide} init fish | source
        enable_transience
        set -gx DIRENV_LOG_FORMAT ""
        set -gx direnv_config_dir ${direnvConfig}
        ${lib.getExe pkgs.direnv} hook fish | source
      end

      # Source user defined `config.fish`
      set config_path ~/.config/fish/config.fish
      # Check if config.fish exists
      if test -e $config_path
          # Source the config file
          echo "Sourcing $config_path"
          source $config_path
      end

      # For it to work on mac, need to put this into local `~/.config/fish/config.fish` for some reason
      # otherwise `/usr/local/bin` will always be higher on mac. :/

      # if not set -q __NIX_DARWIN_PATH_SET
      #     set -gx __NIX_DARWIN_PATH_SET 1
      #     echo "SETTING PATH TO TOP"
      #     set -gx PATH /run/current-system/sw/bin (string match -v /run/current-system/sw/bin $PATH)
      # end

    '';
in {
  wrappers.fish = {
    basePackage = pkgs.fish;
    programs.fish = {
      wrapFlags = [
        "--prefix"
        "XDG_DATA_DIRS"
        ":"
        (lib.makeSearchPathOutput "out" "share" [
          # order matters
          loadPlugin
          fish_user_config
        ])
      ];
    };
  };
}
