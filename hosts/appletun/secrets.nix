{
  age = {
    secrets = {
      login-password = {
        file = ../../secrets/login-password.age;
      };

      wifi-ssid = {
        file = ../../secrets/wifi-ssid.age;
      };

      cloudflared-environment = {
        file = ../../secrets/cloudflared-environment.age;
        owner = "cloudflared";
        group = "cloudflared";
      };
    };
  };
}
