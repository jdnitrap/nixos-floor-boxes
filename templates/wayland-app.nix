# Helpers for boxes that draw through the screen door.
# Import this and set systemd.services.floor-NAME with ExecStart.
{ lib, ... }:
{
  imports = [ ./common-nspawn.nix ];
}
