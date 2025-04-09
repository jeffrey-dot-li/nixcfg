let
  keys = {
    users = {
      jeffreyli = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAICGSYNjWv0dUHvpnYMcvJ4WGy1d54Z1tZV4PeA7luYU1 jeffrey.dot.li@gmail.com";
    };
    systems = {
      appletun = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBDiHx7QSETLcQckR+sYhtDwWIef/2EWsrjAOsHp9BfZ";
      latte = "ssh-ed25519 AAAAC3NzaC1lZDI1NTE5AAAAIBF4pDTAjghAlUlu2084XeJW+ILjaLcJk0gO1Pup5e45 root@latte";
    };
  };
in {
  users = keys.users;
  systems = keys.systems;
  userKeys = builtins.attrValues keys.users;
  systemKeys = builtins.attrValues keys.systems;
}
