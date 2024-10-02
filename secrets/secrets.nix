let
	appletun = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBDiHx7QSETLcQckR+sYhtDwWIef/2EWsrjAOsHp9BfZ";
in {
	"login-password.age".publicKeys = [ appletun ];
	"wifi-ssid.age".publicKeys = [ appletun ];
	"cloudflared-environment.age".publicKeys = [ appletun ];
}
