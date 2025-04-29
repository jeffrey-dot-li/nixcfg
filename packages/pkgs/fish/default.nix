{
  fish,
  fishPlugins,
  lib,
  starship,
  writeTextDir,
  writeText,
  nix-direnv,
  zoxide,
  direnv,
  formats,
  nvim,
}: let
  toml = formats.toml {};
  starship-settings = import ./starship.nix;
  initPlugin = plugin: ''
    begin
      set -l __plugin_dir ${plugin}/share/fish
      if test -d $__plugin_dir/vendor_functions.d
        set -p fish_function_path $__plugin_dir/vendor_functions.d
      end
      if test -d $__plugin_dir/vendor_completions.d
        set -p fish_complete_path $__plugin_dir/vendor_completions.d
      end
      if test -d $__plugin_dir/vendor_conf.d
        for f in $plugin_dir/vendor_conf.d/*.fish
          source $f
        end
      end
    end
  '';
  # TODO: Nixify kitty config
  # TODO: Make it so that we build fish normally first, with plugins
  # Then add configuration after, so it doesn't trigger big rebuild every time
  # I change fish / nvim config
  plugins = with fishPlugins; [foreign-env fzf]; # todo: fzf-fish is broken here on mac
  direnvConfig = writeTextDir "direnvrc" ''
    source ${nix-direnv}/share/nix-direnv/direnvrc
  '';

  fish_user_config = writeText "user_config.fish" ''
    # Only source once
    # set -q __fish_config_sourced; and exit
    # set -gx __fish_config_sourced 1
    ${lib.concatMapStringsSep "\n" initPlugin plugins}
    set -x PATH $HOME/.cargo/bin $PATH

    # Source user defined `config.fish`
    set config_path ~/.config/fish/config.fish
    # Check if config.fish exists
    if test -e $config_path
        # Source the config file
        echo "Sourcing $config_path"
        source $config_path
    end




    if status is-login
      fenv source /etc/profile
    end


    if status is-interactive
      ${lib.fileContents ./interactive.fish}
      ${lib.fileContents ./pushd_mod.fish}
      ${lib.fileContents ./direnv.fish}
      ${lib.fileContents ./open.fish}

      set -gx EDITOR ${lib.getExe nvim}

      set -gx STARSHIP_CONFIG ${toml.generate "starship.toml" starship-settings}
      function starship_transient_prompt_func
        ${lib.getExe starship} module character
      end
      ${lib.getExe starship} init fish | source
      ${lib.getExe zoxide} init fish | source
      enable_transience
      set -gx DIRENV_LOG_FORMAT ""
      set -gx direnv_config_dir ${direnvConfig}
      ${lib.getExe direnv} hook fish | source
    end
  '';
in
  fish.overrideAttrs (old: {
    doCheck = false;
    postInstall =
      old.postInstall
      + ''
        echo "source ${fish_user_config}" >> $out/etc/fish/config.fish
      '';
  })
