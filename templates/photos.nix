# Photos box. Window opens through the screen door (/run/floor-wayland).
# Always opens at least one image so the viewer does not exit on an empty folder.
{ pkgs, lib, ... }:
let
  welcome = pkgs.runCommand "photos-welcome" { } ''
    mkdir -p $out
    ${pkgs.imagemagick}/bin/magick -size 800x500 xc:'#2b4055' \
      -gravity center -fill white -pointsize 36 -annotate 0 'Photos box' \
      "$out/welcome.png"
  '';
in
{
  imports = [ ./wayland-app.nix ];

  environment.systemPackages = [ pkgs.imv ];

  systemd.tmpfiles.rules = [
    "d /root/photos 0755 root root -"
    "L+ /root/photos/welcome.png - - - - ${welcome}/welcome.png"
  ];

  systemd.services.floor-photos = {
    description = "Photos window on the screen door";
    wantedBy = [ "multi-user.target" ];
    after = [ "network.target" ];
    serviceConfig = {
      ExecStart = "${pkgs.imv}/bin/imv /root/photos/welcome.png";
      Restart = "on-failure";
      RestartSec = "3s";
      Environment = [
        "HOME=/root"
        "XDG_RUNTIME_DIR=/run/floor-wayland"
        "WAYLAND_DISPLAY=wayland-0"
      ];
    };
  };
}
