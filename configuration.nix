# Example traditional configuration. Prefer the flake on real machines:
#   imports = [ inputs.nixos-floor-boxes.nixosModules.floorHost ];
{ ... }:
{
  imports = [
    ./hardware-configuration.nix
    ./modules/floor-host.nix
  ];
}
