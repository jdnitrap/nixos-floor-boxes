# Turns share/doors.json into the rules the floor enforces.
# A change to this list is a NixOS rebuild. Starting a box is not.
{ config, lib, pkgs, ... }:
let
  policyFile = ../share/doors.json;
  policy = builtins.fromJSON (builtins.readFile policyFile);
  boxes = policy.boxes;
  knownDoors = [ "screen" "sound" "print" ];
  doorPort = {
    sound = 4713;
    print = 631;
  };

  badDoors = lib.concatLists (lib.mapAttrsToList (name: box:
    lib.filter (door: !(builtins.elem door knownDoors)) box.doors
  ) boxes);

  acceptRules = lib.concatLists (lib.mapAttrsToList (name: box:
    lib.concatMap (door:
      if door == "screen" then [ ]
      else [
        "iptables -A FLOOR-DOORS -s ${box.address.local} -d ${boxes.${door}.address.local} -p tcp --dport ${toString doorPort.${door}} -j ACCEPT"
      ]
    ) box.doors
  ) boxes);
in
{
  assertions = [
    {
      assertion = badDoors == [ ];
      message = "A box lists a door the floor does not know: ${builtins.toString badDoors}";
    }
  ] ++ lib.mapAttrsToList (name: box: {
    assertion =
      if box.window or false then
        builtins.elem "screen" box.doors
        && builtins.match "floor-.*" (box.service or "") != null
      else
        !(builtins.elem "screen" box.doors);
    message = "Box ${name}: window boxes need a screen door and a floor-* service; background boxes must not list screen.";
  }) boxes;

  environment.etc = {
    "floor-boxes/doors.json".source = policyFile;
    # Shared fragments imported by the per-box templates.
    "floor-boxes/templates/common-nspawn.nix".source = ../templates/common-nspawn.nix;
    "floor-boxes/templates/wayland-app.nix".source = ../templates/wayland-app.nix;
  } // lib.mapAttrs' (name: box: {
    name = "floor-boxes/templates/${box.template}";
    value = { source = ../templates + "/${box.template}"; };
  }) boxes;

  boot.kernel.sysctl."net.ipv4.ip_forward" = 1;

  networking.firewall.extraCommands = ''
    iptables -N FLOOR-DOORS 2>/dev/null || iptables -F FLOOR-DOORS
    iptables -C FORWARD -s 10.233.0.0/16 -j FLOOR-DOORS 2>/dev/null || iptables -I FORWARD -s 10.233.0.0/16 -j FLOOR-DOORS
    iptables -A FLOOR-DOORS -m conntrack --ctstate ESTABLISHED,RELATED -j ACCEPT
    ${lib.concatStringsSep "\n" acceptRules}
    iptables -A FLOOR-DOORS -j DROP
  '';

  networking.firewall.extraStopCommands = ''
    iptables -D FORWARD -s 10.233.0.0/16 -j FLOOR-DOORS 2>/dev/null || true
    iptables -F FLOOR-DOORS 2>/dev/null || true
    iptables -X FLOOR-DOORS 2>/dev/null || true
  '';

  systemd.tmpfiles.rules = [
    "d /run/floor-boxes 0755 root root -"
    # 0755 so the firefox box (and other screen-door clients) can reach wayland-0.
    "d /run/floor-boxes/wayland 0755 root root -"
    "d /var/lib/floor-boxes/files 0755 root root -"
  ];
}
