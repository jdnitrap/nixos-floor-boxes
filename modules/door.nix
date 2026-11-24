# The screen box asks the floor through this door. The floor starts the box.
{ pkgs, lib, ... }:
{
  environment.etc."floor-boxes/door.py".source = ../manager/door.py;

  systemd.tmpfiles.rules = [
    "d /run/floor-boxes/door 0755 root root -"
  ];

  systemd.services.floor-box-door = {
    description = "Door the screen box uses to start and stop boxes";
    wantedBy = [ "multi-user.target" ];
    after = [ "systemd-tmpfiles-setup.service" ];
    environment.PATH = lib.mkForce "/run/current-system/sw/bin:/run/wrappers/bin";
    environment.NIX_PATH = "nixpkgs=${pkgs.path}";
    serviceConfig = {
      ExecStart = "${pkgs.python3}/bin/python3 /etc/floor-boxes/door.py";
      Restart = "on-failure";
    };
  };

  systemd.services."container@screen" = {
    after = [ "floor-box-door.service" ];
    wants = [ "floor-box-door.service" ];
  };
}
