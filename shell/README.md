# Get default shell working:

## Mac OS

### Install Nix:
Install Nix with https://nixcademy.com/posts/nix-on-macos/ guide: https://github.com/DeterminateSystems/nix-installer

```sh
curl --proto '=https' --tlsv1.2 -sSf -L https://install.determinate.systems/nix | sh -s -- install
```

### Run configuration script:
```sh
nix run nix-darwin -- switch --flake .\#applin
```

### Test it works
```sh
darwin-rebuild switch --flake .\#applin
```
At this point `nvim` should also be configured. 
Shell environment variable should be set in both `$SHELL` and `cat /etc/shells` (it will resolve to something like `/nix/store/js5ylmh31vk4zr23vs9jasj1s51rz43f-wrapper-manager/bin/nucleus`).

Last just configure system to use it as default shell in `~/.zprofile`:
```sh
if [ "$__USER_SHELL_SOURCED" = "1" ]; then
    return
fi
__USER_SHELL_SOURCED=1
export SHELL=$(dscl . -read /Users/$USER UserShell | sed 's/UserShell: //')
exec $SHELL
```



