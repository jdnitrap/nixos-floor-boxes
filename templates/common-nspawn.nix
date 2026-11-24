# Shared settings for every template box.
# Imperative nixos-container builds fail if nscd is off without clearing nssModules.
{ lib, ... }:
{
  services.nscd.enable = false;
  system.nssModules = lib.mkForce [ ];
}
