# Job boxes are built with the floor system on the host. The test VM only
# starts those finished systems. It cannot write new files into the Nix store.
{ lib, ... }:
let
  policy = builtins.fromJSON (builtins.readFile ../share/doors.json);
in
{
  systemd.tmpfiles.rules = [
    "d /var/lib/floor-boxes/files 0755 root root -"
  ];

  containers = lib.mapAttrs (name: box: {
    autoStart = false;
    privateNetwork = true;
    hostAddress = box.address.host;
    localAddress = box.address.local;
    bindMounts = {
      "/etc/floor-doors.json" = {
        hostPath = "/etc/floor-boxes/doors.json";
        isReadOnly = true;
      };
    }
    // lib.optionalAttrs (box.owns or "" == "speakers") {
      "/dev/snd" = {
        hostPath = "/dev/snd";
        isReadOnly = false;
      };
    }
    // lib.optionalAttrs (box.owns or "" == "printer") {
      "/dev/bus/usb" = {
        hostPath = "/dev/bus/usb";
        isReadOnly = false;
      };
    }
    // lib.optionalAttrs (box.owns or "" == "files") {
      "/srv/files" = {
        hostPath = "/var/lib/floor-boxes/files";
        isReadOnly = false;
      };
    }
    // lib.optionalAttrs (lib.elem "screen" (box.doors or [ ])) {
      "/run/floor-wayland" = {
        hostPath = "/run/floor-boxes/wayland";
        isReadOnly = false;
      };
    };
    config = { lib, ... }: {
      imports = [ ../templates/${box.template} ];
      system.stateVersion = "26.05";
      networking.useHostResolvConf = lib.mkIf (lib.elem "network" (box.doors or [ ])) (lib.mkForce false);
      networking.nameservers = lib.mkIf (lib.elem "network" (box.doors or [ ])) [ "10.233.8.2" ];
    };
  }) policy.boxes;
}
