# Start a clean ZSH

```sh
env -i PATH="/opt/homebrew/bin:/bin:/usr/bin:/usr/sbin:/sbin" /bin/zsh  -l -f
```


# SSH on mac

```sh
# ssh-add --apple-use-keychain ~/.ssh/id_ed25519
Host *
    AddKeysToAgent yes
    UseKeychain yes
    IdentityFile ~/.ssh/id_ed25519
```