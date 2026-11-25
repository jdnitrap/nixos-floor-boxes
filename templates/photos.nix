# Photos box. Window opens through the screen door (/run/floor-wayland).
# Self-contained (no imports): nixos-container evaluates this as a single file.
{ pkgs, lib, ... }:
let
  welcome = pkgs.runCommand "photos-welcome" {
    FONTCONFIG_FILE = pkgs.makeFontsConf { fontDirectories = [ pkgs.dejavu_fonts ]; };
  } ''
    mkdir -p "$out" "$TMPDIR/fontconfig"
    export HOME="$TMPDIR"
    export XDG_CACHE_HOME="$TMPDIR/fontconfig"
    ${pkgs.imagemagick}/bin/magick -size 800x500 xc:'#2b4055' \
      -font ${pkgs.dejavu_fonts}/share/fonts/truetype/DejaVuSans.ttf \
      -gravity center -fill white -pointsize 36 -annotate 0 'Photos box' \
      "$out/welcome.png"
  '';
in
{
  services.nscd.enable = false;
  system.nssModules = lib.mkForce [ ];

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
