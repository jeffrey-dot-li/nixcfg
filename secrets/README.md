ssh-keyscan xxx

nix run github:ryantm/agenix -- -e secret1.age

sudo bat /run/agenix/passwords

Note: Login Passwords are actually *hashed*!!! If you store them as plaintext you will lock yourself out. 
https://search.nixos.org/options?show=users.users.%3Cname%3E.hashedPassword
Use `mkpasswd` to generate password hash.
