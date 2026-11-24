# Firefox box. Window opens through the screen door (/run/floor-wayland).
# Self-contained (no imports): nixos-container evaluates this as a single file.
{ pkgs, lib, ... }:
{
  services.nscd.enable = false;
  system.nssModules = lib.mkForce [ ];

  environment.systemPackages = [ pkgs.firefox pkgs.hicolor-icon-theme ];

  systemd.services.floor-firefox = {
    description = "Firefox on the screen door";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.firefox}/bin/firefox --no-remote --class floor-firefox";
      Restart = "on-failure";
      RestartSec = "3s";
      Environment = [
        "HOME=/root"
        "XDG_RUNTIME_DIR=/run/floor-wayland"
        "WAYLAND_DISPLAY=wayland-0"
        "MOZ_ENABLE_WAYLAND=1"
        "GDK_BACKEND=wayland"
      ];
    };
  };
}
