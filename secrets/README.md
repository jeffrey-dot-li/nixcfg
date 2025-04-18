# Steps to create a new secret:
Assume we want to create `wifi/network1.age` which would be 
```
WIFI_SSID="..."
SSID_PASSWORD="..."
```

Then we would do the following:

1. Add to `secrets.nix`, with the ssh keys set up:
Specifically, would look like: 
`  "wifi/empress.age".publicKeys = [keys.systems.appletun keys.systems.latte keys.users.jeffreyli];` where need both *system* and *user* keys. The *system* key is what the system will use to decrypt the key, and it is stored in `/etc/ssh/ssh_host_ed25519_key`. The *user* key is what the user will use to edit the key, and it will generally be stored in `~/.ssh/id_ed25519`.

2. Create the file `wifi/network1.age`: 
`agenix -e wifi/network1.age`
Note that this will use the user's current ssh key to write, and will make this file decryptable by any key listed in the publicKeys list in `secrets.nix`. This is why we don't have to use the argument `-i /etc/ssh/ssh_host_ed25519_key` here - because even though we encrypt with the user's key, the system key is also listed in `secrets.nix`, so it can decrypt it.
Can check which key the user is using with `ssh-add -l`.

3. Check the file is created and readable by system:
```sh
sudo agenix -d wifi/network1.age -i /etc/ssh/ssh_host_ed25519_key
```




For nixos systems, find ed25519 key in `/etc/ssh/ssh_host_ed25519_key.pub` and add it to your github account.

```sh
ssh-keyscan xxx

nix run github:ryantm/agenix -- -e secret1.age

sudo bat /run/agenix/passwords

sudo -E agenix -e cloudflared-environment.age -i /etc/ssh/ssh_host_ed25519_key
```

Note: Login Passwords are actually *hashed*!!! If you store them as plaintext you will lock yourself out. 
https://search.nixos.org/options?show=users.users.%3Cname%3E.hashedPassword
Use `mkpasswd` to generate password hash.