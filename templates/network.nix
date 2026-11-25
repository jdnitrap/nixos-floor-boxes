# Network box. Owns the way out. Other boxes reach the internet through this door.
# Self-contained (no imports): nixos-container evaluates this as a single file.
{ lib, ... }:
{
  services.nscd.enable = false;
  system.nssModules = lib.mkForce [ ];

  services.dnsmasq = {
    enable = true;
    settings = {
      port = 53;
      bind-interfaces = true;
      listen-address = "10.233.8.2";
      no-resolv = true;
      server = [ "1.1.1.1" "9.9.9.9" ];
    };
  };

  networking.firewall.allowedUDPPorts = [ 53 ];
  networking.firewall.allowedTCPPorts = [ 53 ];
}
