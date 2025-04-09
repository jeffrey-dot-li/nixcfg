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