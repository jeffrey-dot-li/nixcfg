# Cloudflared token format: (THIS IS WHAT YOU PUT IN THE `cloudflared-environement.age` FILE)
https://developers.cloudflare.com/cloudflare-one/connections/connect-networks/configure-tunnels/tunnel-run-parameters/#token
`TUNNEL_TOKEN="ey..."`

Can check with `TUNNEL_TOKEN="ey..." cloudflared tunnel --no-autoupdate run`

sudo -E agenix -e cloudflared-environment.age -i /etc/ssh/ssh_host_ed25519_key
agenix -e cloudflared-environment.age