# Sensible floor host defaults. Import floor modules plus login/network basics.
# Pair with hardware-configuration.nix from the NixOS installer.
{ pkgs, ... }:
{
  imports = [ ./floor.nix ];

  networking.hostName = "floor";
  networking.networkmanager.enable = true;
  services.openssh.enable = true;

  users.users.floor = {
    isNormalUser = true;
    extraGroups = [ "wheel" ];
    description = "Floor login";
  };

  environment.systemPackages = [ pkgs.vim ];

  # No desktop and no AI on the floor. The screen is its own box.
  system.stateVersion = "26.05";
}
