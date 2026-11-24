# Sound box. Owns the speakers. No screen window — other boxes use the sound door.
{ pkgs, lib, ... }:
{
  imports = [ ./common-nspawn.nix ];

  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
  };

  # Listen so other boxes can reach pulse through the sound door (TCP 4713).
  services.pipewire.extraConfig.pipewire-pulse."50-floor-network" = {
    "pulse.properties" = {
      "server.address" = [
        "unix:native"
        "tcp:0.0.0.0:4713"
      ];
    };
  };

  networking.firewall.allowedTCPPorts = [ 4713 ];
}
