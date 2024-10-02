{
  pkgs,
  aliasesStr,
}:
pkgs.writeScript "config.fish" ''

export STARSHIP_SHELL=fish
${aliasesStr}

starship init fish | source
zoxide init fish | source
''
