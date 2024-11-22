{
  pkgs,
  aliasesStr,
}: let
  foreign-env-fish = pkgs.fetchFromGitHub {
    owner = "oh-my-fish";
    repo = "plugin-foreign-env";
    rev = "7f0cf099ae1e1e4ab38f46350ed6757d54471de7";
    sha256 = "sha256-4+k5rSoxkTtYFh/lEjhRkVYa2S4KEzJ/IJbyJl+rJjQ=";
  };
in
  pkgs.writeScript "config.fish" ''
    set fish_function_path $fish_function_path ${foreign-env-fish}/functions
    export STARSHIP_SHELL=fish
    set PATH $PATH ~/.cargo/bin

    ${aliasesStr}

    starship init fish | source
    zoxide init fish | source
  ''
