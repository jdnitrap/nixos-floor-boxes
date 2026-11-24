# Files box. Window opens through the screen door (/run/floor-wayland).
# Self-contained (no imports): nixos-container evaluates this as a single file.
{ pkgs, lib, ... }:
{
  services.nscd.enable = false;
  system.nssModules = lib.mkForce [ ];

  environment.systemPackages = [ pkgs.pcmanfm pkgs.hicolor-icon-theme pkgs.adwaita-icon-theme ];

  systemd.tmpfiles.rules = [ "d /srv/files 0755 root root -" ];

  systemd.services.floor-files = {
    description = "Files window on the screen door";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.pcmanfm}/bin/pcmanfm /srv/files";
      Restart = "on-failure";
      RestartSec = "3s";
      Environment = [
        "HOME=/root"
        "XDG_RUNTIME_DIR=/run/floor-wayland"
        "WAYLAND_DISPLAY=wayland-0"
        "GDK_BACKEND=wayland"
      ];
    };
  };
}
