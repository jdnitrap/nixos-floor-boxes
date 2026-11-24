# Mail box. Window opens through the screen door (/run/floor-wayland).
{ pkgs, lib, ... }:
{
  imports = [ ./wayland-app.nix ];

  environment.systemPackages = [ pkgs.thunderbird pkgs.hicolor-icon-theme ];

  systemd.services.floor-mail = {
    description = "Mail window on the screen door";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.thunderbird}/bin/thunderbird --class floor-mail";
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
