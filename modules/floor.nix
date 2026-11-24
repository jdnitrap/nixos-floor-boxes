# Modules for the floor. configuration.nix imports this file.
{ ... }:
{
  imports = [
    ./policy.nix
    ./door.nix
    ./screen.nix
  ];
}
