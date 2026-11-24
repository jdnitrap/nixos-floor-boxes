# Print box. Owns the printer. No screen window — other boxes use the print door.
# Self-contained (no imports): nixos-container evaluates this as a single file.
{ lib, ... }:
{
  services.nscd.enable = false;
  system.nssModules = lib.mkForce [ ];

  services.printing = {
    enable = true;
    listenAddresses = [ "*:631" ];
    allowFrom = [ "all" ];
    defaultShared = true;
  };

  networking.firewall.allowedTCPPorts = [ 631 ];
}
