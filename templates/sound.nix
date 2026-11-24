# Sound box. Owns the speakers. No screen window — other boxes use the sound door.
# Self-contained (no imports): nixos-container evaluates this as a single file.
{ pkgs, lib, ... }:
{
  services.nscd.enable = false;
  system.nssModules = lib.mkForce [ ];

  services.pipewire = {
    enable = true;
    pulse.enable = true;
    alsa.enable = true;
  };

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
