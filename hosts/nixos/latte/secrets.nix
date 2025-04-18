{
  age = {
    secrets = {
      cloudflared-environment = {
        file = ../../../secrets/cloudflared-environment.age;
        owner = "cloudflared";
        group = "cloudflared";
      };
      wifi-ssid = {
        file = ../../../secrets/wifi/empress.age;
      };
    };
  };
}
