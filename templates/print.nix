# Print box. Owns the printer. No screen window — other boxes use the print door.
{ lib, ... }:
{
  imports = [ ./common-nspawn.nix ];

  services.printing = {
    enable = true;
    listenAddresses = [ "*:631" ];
    allowFrom = [ "all" ];
    defaultShared = true;
  };

  networking.firewall.allowedTCPPorts = [ 631 ];
}
