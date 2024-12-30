function nixify
    if test ! -e .envrc
        echo "use nix" > .envrc
        direnv allow
    end
    
    if test ! -e shell.nix; and test ! -e default.nix
        echo 'with import <nixpkgs> {};
mkShell {
  nativeBuildInputs = [
    bashInteractive
  ];
}' > default.nix
        eval $EDITOR default.nix 2>/dev/null; or vim default.nix
    end
end

function flakify
    if test ! -e flake.nix
        nix flake new -t github:nix-community/nix-direnv .
    else if test ! -e .envrc
        echo "use flake" > .envrc
        direnv allow
    end
    
    eval $EDITOR flake.nix 2>/dev/null; or vim default.nix
end